#!/usr/bin/env python3
"""VieNeu-TTS v3 Turbo — reference runner for the Dart port (dev tool).

Port target: ``src/vieneu/_v3_turbo_engine/onnx_runtime_lite.py`` from
``pnnbao97/VieNeu-TTS``. This script is *not* shipped: it exists so the Dart
implementation can be checked against the real model on the same machine, in two
ways the Dart tests cannot check on their own:

1. ``test/fixtures/vieneu_tokenizer_golden.json`` — phoneme strings encoded by
   the official HuggingFace ``tokenizers`` library against the exact
   ``tokenizer.json`` that ships with the checkpoint. A hand-written BPE that
   *looks* right but disagrees here would silently degrade every sentence.
2. ``test/fixtures/vieneu_pipeline_golden.json`` — prompt rows, embedding
   checksum, prefill checksum and the first frames of a *greedy* decode. Greedy
   means deterministic, so Dart can reproduce these numbers exactly.

Also writes a listenable WAV (sampled, not greedy) to ``.cache/golden/`` so the
audio path can be judged by ear, not only by an RMS assertion.

Everything it needs lives in ``assets/models/`` (gitignored, dev-time staging):

    python3 tool/reference/vieneu_reference.py

Requires: onnxruntime, numpy, tokenizers (plot-form scope: dev only).
"""

from __future__ import annotations

import ctypes
import json
import math
import sys
import wave
from pathlib import Path

import numpy as np
import onnxruntime as ort

REPO = Path(__file__).resolve().parents[2]
MODELS = REPO / "assets" / "models"
V3 = MODELS / "vieneu_v3_turbo_int8"
CODEC = MODELS / "moss_audio_tokenizer_nano"
G2P_LIB = MODELS / "sea_g2p" / "libsea_g2p_rs-linux-x86_64.so"
G2P_BIN = MODELS / "sea_g2p" / "sea_g2p.bin"
VOICES = REPO / "assets" / "voices" / "voices_v3_turbo.json"
FIXTURES = REPO / "test" / "fixtures"
GOLDEN_DIR = REPO / ".cache" / "golden"

# ── frame-cap constants, mirrored from vieneu_utils.core_utils ────────────────
FRAME_CAP_SLACK = 24
MAX_FRAMES_PER_PHONE = 2.0
SINGLE_WORD_MAX_FRAMES = 13
SYLLABLE_CAP_PER_EXTRA = 5
SYLLABLE_CAP_MAX_SYL = 4
SINGLE_WORD_MAX_PHONES = 24
CODEC_SAMPLES_PER_FRAME = 3840

_IPA_VOWELS = set("aeiouyæɐɑɒɔəɘɛɜɤɯɵøœʉʊʌɪɨɚɝᵻᵿ")


class SeaG2P:
    """ctypes binding to the sea-g2p C ABI — the same surface Dart will use."""

    def __init__(self, lib_path: Path, dict_path: Path):
        self._lib = ctypes.CDLL(str(lib_path))
        self._lib.sea_g2p_abi_version.restype = ctypes.c_int
        self._lib.sea_g2p_open.restype = ctypes.c_void_p
        self._lib.sea_g2p_open.argtypes = [ctypes.c_char_p]
        self._lib.sea_g2p_close.argtypes = [ctypes.c_void_p]
        self._lib.sea_g2p_phonemize.restype = ctypes.c_void_p
        self._lib.sea_g2p_phonemize.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
        self._lib.sea_g2p_last_error.restype = ctypes.c_char_p
        self._lib.sea_g2p_string_free.argtypes = [ctypes.c_void_p]

        abi = self._lib.sea_g2p_abi_version()
        if abi != 1:
            raise RuntimeError(f"sea-g2p ABI {abi} != 1")
        self._h = self._lib.sea_g2p_open(str(dict_path).encode())
        if not self._h:
            raise RuntimeError(f"sea_g2p_open failed: {self._last_error()}")

    def _last_error(self) -> str:
        e = self._lib.sea_g2p_last_error()
        return e.decode("utf-8", "replace") if e else "(no message)"

    def phonemize(self, text: str, punc_norm: bool = True) -> str:
        ptr = self._lib.sea_g2p_phonemize(self._h, text.encode(), 1 if punc_norm else 0)
        if not ptr:
            raise RuntimeError(f"sea_g2p_phonemize failed: {self._last_error()}")
        try:
            return ctypes.string_at(ptr).decode("utf-8")
        finally:
            self._lib.sea_g2p_string_free(ptr)


def softmax(x: np.ndarray) -> np.ndarray:
    x = x - np.max(x)
    e = np.exp(x)
    return e / np.sum(e)


def syllable_count(phonemes: str) -> int:
    import re
    stripped = re.sub(r"<\|emotion_\d+\|>|</?en>", "", phonemes or "")
    total = 0
    for tok in stripped.split():
        groups, in_v, consonant_seen = 0, False, True
        for ch in tok:
            if ch in _IPA_VOWELS:
                if not in_v and consonant_seen:
                    groups += 1
                in_v, consonant_seen = True, False
            elif ch in "ːˈˌ" or ch.isdigit():
                pass
            else:
                in_v, consonant_seen = False, True
        total += max(groups, 1) if groups else 0
    return total


def max_expected_frames(phonemes: str) -> int:
    import re
    stripped = re.sub(r"<\|emotion_\d+\|>|</?en>", "", phonemes or "")
    cap = FRAME_CAP_SLACK + int(math.ceil(MAX_FRAMES_PER_PHONE * len(stripped)))
    syl = max(1, syllable_count(phonemes))
    if syl <= SYLLABLE_CAP_MAX_SYL and len(stripped) <= SINGLE_WORD_MAX_PHONES * syl:
        cap = min(cap, SINGLE_WORD_MAX_FRAMES + SYLLABLE_CAP_PER_EXTRA * (syl - 1))
    return cap


class ReferenceEngine:
    def __init__(self, threads: int = 0):
        cfg = json.loads((V3 / "config.json").read_text(encoding="utf-8"))
        self.cfg = cfg
        self.n_vq = int(cfg["n_vq"])
        self.hidden = int(cfg["hidden_size"])
        self.L = int(cfg["num_hidden_layers"])
        self.L_loc = int(cfg.get("local_num_hidden_layers", 1))
        self.nH_loc = int(cfg.get("local_num_attention_heads", 8))
        self.hd_loc = self.hidden // self.nH_loc
        self.audio_pad = int(cfg["audio_pad_token_id"])
        self.tps = int(cfg["text_prompt_start_token_id"])
        self.tpe = int(cfg["text_prompt_end_token_id"])
        self.sgs = int(cfg["speech_generation_start_token_id"])
        self.eos_speech = int(cfg["speech_generation_end_token_id"])
        self.ref_slot = int(cfg["audio_ref_slot_token_id"])
        self.default_style_id = int(cfg.get("default_style_token_id", 16))
        self.sample_rate = int(cfg.get("audio_sample_rate", 48_000))

        z = np.load(V3 / "vieneu_v3_heads.npz")
        self.text_emb = z["text_emb"].astype(np.float32)
        self.audio_emb = z["audio_emb"].astype(np.float32)
        self.xvec_w = z["xvec_w"].astype(np.float32)
        self.xvec_b = z["xvec_b"].astype(np.float32)
        self.xvec_ln_w = z["xvec_ln_w"].astype(np.float32)
        self.xvec_ln_b = z["xvec_ln_b"].astype(np.float32)
        self.xvec_ln_eps = float(z["xvec_ln_eps"])

        from tokenizers import Tokenizer
        self.tokenizer = Tokenizer.from_file(str(V3 / "tokenizer.json"))

        so = ort.SessionOptions()
        so.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        so.inter_op_num_threads = 1
        so.intra_op_num_threads = threads or min(max((__import__("os").cpu_count() or 8) // 2, 1), 8)
        self.sess_pre = ort.InferenceSession(str(V3 / "vieneu_prefill.onnx"), so, providers=["CPUExecutionProvider"])
        self.sess_dec = ort.InferenceSession(str(V3 / "vieneu_decode_step.onnx"), so, providers=["CPUExecutionProvider"])
        self.sess_ac = ort.InferenceSession(str(V3 / "vieneu_acoustic_cached.onnx"), so, providers=["CPUExecutionProvider"])
        self.sess_codec_dec = ort.InferenceSession(str(CODEC / "moss_audio_tokenizer_decode_full.onnx"), so, providers=["CPUExecutionProvider"])

        self.voices = json.loads(VOICES.read_text(encoding="utf-8"))["presets"]

    # ── numpy helpers (mirror onnx_runtime_lite) ─────────────────────────────
    def speaker_anchor(self, speaker_emb) -> np.ndarray:
        v = np.asarray(speaker_emb, dtype=np.float32).reshape(-1)
        v = v @ self.xvec_w.T + self.xvec_b
        v = (v - v.mean()) / np.sqrt(v.var() + self.xvec_ln_eps)
        return (v * self.xvec_ln_w + self.xvec_ln_b).astype(np.float32)

    def embed_rows(self, rows: np.ndarray, anchor) -> np.ndarray:
        emb = self.text_emb[rows[:, 0]]
        for ch in range(self.n_vq):
            ids = rows[:, ch + 1]
            valid = ids != self.audio_pad
            safe = np.where(valid, ids, 0)
            emb = emb + self.audio_emb[ch][safe] * valid[:, None]
        if anchor is not None:
            emb = emb + anchor[None]
        return emb[None].astype(np.float32)

    def build_rows(self, phonemes: str, ref_codes, style_id: int) -> np.ndarray:
        phone_ids = self.tokenizer.encode(phonemes, add_special_tokens=False).ids
        text_ids = [style_id, self.tps] + list(phone_ids) + [self.tpe]
        rows = np.full((len(text_ids), self.n_vq + 1), self.audio_pad, dtype=np.int64)
        rows[:, 0] = text_ids
        if ref_codes is None:
            return rows
        rc = np.asarray(ref_codes, dtype=np.int64)
        ref = np.full((rc.shape[0], self.n_vq + 1), self.audio_pad, dtype=np.int64)
        ref[:, 0] = self.ref_slot
        ref[:, 1:] = rc
        return np.concatenate([rows, ref], axis=0)

    def sample(self, logits, temperature, top_k, top_p, rep_pen, prev):
        logits = logits.astype(np.float32)
        if not math.isclose(rep_pen, 1.0) and prev:
            idx = np.fromiter(prev, dtype=np.int64, count=len(prev))
            sel = logits[idx]
            logits = logits.copy()
            logits[idx] = np.where(sel < 0, sel * rep_pen, sel / rep_pen)
        if not (temperature and temperature > 0):
            return int(logits.argmax())
        logits = logits / temperature
        V = logits.shape[-1]
        if top_k and 0 < int(top_k) < V:
            k = int(top_k)
            cand = np.argpartition(logits, -k)[-k:]
        else:
            cand = np.arange(V)
        cs = logits[cand]
        order = np.argsort(cs)[::-1]
        cand = cand[order]
        p = softmax(cs[order])
        if top_p and top_p < 1.0:
            keep = (np.cumsum(p) - p) < top_p
            p = p * keep
            p = p / p.sum()
        return int(cand[np.random.choice(cand.shape[-1], p=p)])

    def empty_past(self):
        empty = np.zeros((1, self.nH_loc, 0, self.hd_loc), dtype=np.float32)
        feed = {}
        for i in range(self.L_loc):
            feed[f"past_k_{i}"] = empty
            feed[f"past_v_{i}"] = empty
        return feed

    @staticmethod
    def split_past(out, L):
        return out[1:1 + L], out[1 + L:1 + 2 * L]

    def past_feed(self, pk, pv):
        feed = {}
        for i in range(self.L_loc):
            feed[f"past_k_{i}"] = pk[i]
            feed[f"past_v_{i}"] = pv[i]
        return feed

    def acoustic_frame(self, h, temperature, top_k, top_p, rep_pen, hist):
        H = self.hidden
        cond = h[0].astype(np.float32)
        txt = self.text_emb[self.sgs].astype(np.float32)
        tok = np.stack([cond, txt])[None].astype(np.float32)
        feed = {"token_emb": tok, "position_ids": np.array([[0, 1]], np.int64)}
        feed.update(self.empty_past())
        out = self.sess_ac.run(None, feed)
        hidden = out[0]
        pk, pv = self.split_past(out, self.L_loc)
        slot0 = hidden[0, 0]

        def samp(ch, vec):
            logits = vec.astype(np.float32) @ self.audio_emb[ch].T
            prev = hist[ch] if hist is not None else None
            code = self.sample(logits, temperature, top_k, top_p, rep_pen, prev)
            if hist is not None:
                hist[ch].append(code)
            return code

        codes = [samp(0, hidden[0, 1])]
        for ch in range(1, self.n_vq):
            emb = self.audio_emb[ch - 1][codes[-1]].astype(np.float32)
            feed = {"token_emb": emb.reshape(1, 1, H), "position_ids": np.array([[ch + 1]], np.int64)}
            feed.update(self.past_feed(pk, pv))
            out = self.sess_ac.run(None, feed)
            hidden = out[0]
            pk, pv = self.split_past(out, self.L_loc)
            codes.append(samp(ch, hidden[0, 0]))
        text_logits = slot0.astype(np.float32) @ self.text_emb.T
        eos = int(text_logits.argmax()) == self.eos_speech
        return codes, eos

    def decode_codes(self, codes: np.ndarray) -> np.ndarray:
        c = np.asarray(codes, dtype=np.int32)[None]
        lens = np.array([c.shape[1]], dtype=np.int32)
        out = self.sess_codec_dec.run(None, {"audio_codes": c, "audio_code_lengths": lens})
        return out[0][0].mean(0).astype(np.float32)

    def generate(self, phonemes, speaker_emb, ref_codes, *, temperature=0.8, top_k=25,
                 top_p=0.95, max_new_frames=300, rep_pen=1.2, rep_window=64,
                 frame_cap=True, seed=None, trace=None):
        if seed is not None:
            np.random.seed(seed)
        if frame_cap:
            max_new_frames = min(max_new_frames, max_expected_frames(phonemes))
        anchor = self.speaker_anchor(speaker_emb)
        rows = self.build_rows(phonemes, ref_codes if ref_codes is not None else None, self.default_style_id)
        prompt_embeds = self.embed_rows(rows, anchor)

        if trace is not None:
            trace["rows"] = rows.tolist()
            trace["prompt_embeds_sum"] = float(prompt_embeds.sum())
            trace["prompt_embeds_abs_sum"] = float(np.abs(prompt_embeds).sum())
            trace["anchor"] = anchor.tolist()[:8]

        pre = self.sess_pre.run(None, {"inputs_embeds": prompt_embeds})
        past_k = [pre[1 + i] for i in range(self.L)]
        past_v = [pre[1 + self.L + i] for i in range(self.L)]
        h = pre[0][:, -1]
        if trace is not None:
            trace["prefill_hidden_shape"] = list(pre[0].shape)
            trace["prefill_hidden_sum"] = float(pre[0].sum())
            trace["prefill_last_row"] = [float(x) for x in pre[0][0, -1, :8]]
            trace["past_k_0_shape"] = list(pre[1].shape)
        Tprompt = prompt_embeds.shape[1]

        hist = [[] for _ in range(self.n_vq)] if not math.isclose(rep_pen, 1.0) else None
        frames = []
        for t in range(max_new_frames):
            codes, eos = self.acoustic_frame(h, temperature, top_k, top_p, rep_pen, hist)
            frames.append(np.asarray(codes, dtype=np.int64))
            if eos:
                break
            slot = np.full((1, 1, self.n_vq + 1), self.audio_pad, dtype=np.int64)
            slot[:, :, 0] = self.sgs
            slot[0, 0, 1:] = codes
            se = self.embed_rows(slot[0], anchor)
            feed = {"inputs_embeds": se, "position_ids": np.array([[Tprompt + t]], np.int64)}
            for i in range(self.L):
                feed[f"past_k_{i}"] = past_k[i]
                feed[f"past_v_{i}"] = past_v[i]
            out = self.sess_dec.run(None, feed)
            h = out[0][:, 0]
            past_k = [out[1 + i] for i in range(self.L)]
            past_v = [out[1 + self.L + i] for i in range(self.L)]
        if not frames:
            return np.zeros(0, dtype=np.float32), []
        return self.decode_codes(np.stack(frames)), frames


def write_wav(path: Path, samples: np.ndarray, sr: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.clip(samples, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


GOLDEN_SENTENCES = [
    "Xin chào, đây là bản thử nghiệm đọc tiếng Việt trên thiết bị.",
    "Giá SP500 hôm nay là 4.200,5 điểm.",
    "Hôm nay trời đẹp quá!",
    "Tôi tên là Nguyễn Văn A, sinh năm 1995.",
]


def main() -> int:
    engine = ReferenceEngine()
    g2p = SeaG2P(G2P_LIB, G2P_BIN)
    print("sea-g2p ABI ok, models loaded")
    for name in ("prefill", "decode_step", "acoustic", "codec"):
        sess = {"prefill": engine.sess_pre, "decode_step": engine.sess_dec,
                "acoustic": engine.sess_ac, "codec": engine.sess_codec_dec}[name]
        print(f"  {name}: in={[i.name for i in sess.get_inputs()]}")

    # ── 1. tokenizer goldens (official HF tokenizers) ────────────────────────
    tokenizer_golden = []
    for text in GOLDEN_SENTENCES:
        phonemes = g2p.phonemize(text)
        ids = engine.tokenizer.encode(phonemes, add_special_tokens=False).ids
        tokenizer_golden.append({"text": text, "phonemes": phonemes, "ids": ids})
    FIXTURES.mkdir(parents=True, exist_ok=True)
    (FIXTURES / "vieneu_tokenizer_golden.json").write_text(
        json.dumps({"note": "generated by tool/reference/vieneu_reference.py with HF tokenizers",
                    "cases": tokenizer_golden}, ensure_ascii=False, indent=1),
        encoding="utf-8")
    print(f"tokenizer goldens: {len(tokenizer_golden)} cases")

    # ── 2. pipeline golden (greedy → deterministic) ──────────────────────────
    voice_id = "Hải Đăng"
    voice = engine.voices[voice_id]
    sentence = GOLDEN_SENTENCES[0]
    phonemes = g2p.phonemize(sentence)
    trace: dict = {"voice": voice_id, "sentence": sentence, "phonemes": phonemes}
    wav, frames = engine.generate(
        phonemes, voice["speaker_emb"], np.asarray(voice["codes"], dtype=np.int64),
        temperature=0.0, top_k=0, top_p=1.0, rep_pen=1.0, frame_cap=False,
        trace=trace,
    )
    trace["greedy_frames"] = [list(map(int, f)) for f in frames[:8]]
    trace["greedy_frame_count"] = len(frames)
    trace["ref_codes_shape"] = list(np.asarray(voice["codes"]).shape)
    FIXTURES.mkdir(parents=True, exist_ok=True)
    (FIXTURES / "vieneu_pipeline_golden.json").write_text(
        json.dumps(trace, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"pipeline golden: {trace['greedy_frame_count']} greedy frames, "
          f"hidden shape {trace['prefill_hidden_shape']}")

    # ── 3. listenable reference audio (default sampling) ─────────────────────
    for voice_id in ("Hải Đăng", "Trúc Ly"):
        voice = engine.voices[voice_id]
        phonemes = g2p.phonemize(GOLDEN_SENTENCES[0])
        wav, frames = engine.generate(
            phonemes, voice["speaker_emb"], np.asarray(voice["codes"], dtype=np.int64),
            seed=1234,
        )
        rms = float(np.sqrt(np.mean(wav ** 2))) if wav.size else 0.0
        out = GOLDEN_DIR / f"reference_{voice_id.replace(' ', '_')}.wav"
        write_wav(out, wav, engine.sample_rate)
        print(f"{voice_id}: {len(frames)} frames, {wav.size / engine.sample_rate:.2f}s, "
              f"rms={rms:.4f} -> {out.relative_to(REPO)}")
        if rms < 1e-3:
            print("  !! SILENT — the port would be wrong")
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
