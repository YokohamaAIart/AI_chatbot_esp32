#!/usr/bin/env python3
"""Add NVIDIA Parakeet-TDT (sherpa-onnx `nemo_transducer`) to xiaozhi-server's SherpaASR provider.

Upstream SherpaASR only knows sense_voice / paraformer (single model.int8.onnx).
Parakeet ships encoder/decoder/joiner. Idempotent. Run from main/xiaozhi-server.
"""
import pathlib
import sys

P = pathlib.Path("core/providers/asr/sherpa_onnx_local.py")
src = P.read_text(encoding="utf-8")
if "nemo_transducer" in src:
    print("already patched")
    sys.exit(0)

# 1. skip the SenseVoice auto-download/check for transducer models
old_dl = """        # 初始化模型文件路径
        model_files = {"""
new_dl = """        if self.model_type == "nemo_transducer":
            self._init_transducer()
            return

        # 初始化模型文件路径
        model_files = {"""
assert old_dl in src, "anchor 1 not found — upstream changed"
src = src.replace(old_dl, new_dl, 1)

# 2. transducer loader
old_rw = "    def read_wave(self, wave_filename: str)"
new_rw = '''    def _init_transducer(self):
        d = self.model_dir
        files = {k: os.path.join(d, f"{k}.int8.onnx") for k in ("encoder", "decoder", "joiner")}
        files["tokens"] = os.path.join(d, "tokens.txt")
        missing = [p for p in files.values() if not os.path.isfile(p)]
        if missing:
            raise FileNotFoundError(f"Parakeet model files missing: {missing}")
        with CaptureOutput():
            self.model = sherpa_onnx.OfflineRecognizer.from_transducer(
                encoder=files["encoder"],
                decoder=files["decoder"],
                joiner=files["joiner"],
                tokens=files["tokens"],
                num_threads=2,
                sample_rate=16000,
                feature_dim=80,
                decoding_method="greedy_search",
                model_type="nemo_transducer",
                debug=False,
            )

    def read_wave(self, wave_filename: str)'''
assert old_rw in src, "anchor 2 not found — upstream changed"
src = src.replace(old_rw, new_rw, 1)

P.write_text(src, encoding="utf-8")
print("patched", P)
