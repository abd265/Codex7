# Speech model notices

Darja Together uses the requested `touati-kamel/f5tts-algerian-darja` checkpoint as a local speech-generation dependency. Model weights stay outside the iPhone app source tree. Generated speech remains synthetic; it is not a recording of a native Darja teacher or a pronunciation assessment.

## Pinned upstream assets

| Repository | Immutable revision | Files used |
| --- | --- | --- |
| [touati-kamel/f5tts-algerian-darja](https://huggingface.co/touati-kamel/f5tts-algerian-darja/tree/0589d128f0d0de70780a1e46cc425eb8cfa05d6b) | `0589d128f0d0de70780a1e46cc425eb8cfa05d6b` | `model_last.pt` (3,542,591,049 bytes), model card |
| [IbrahimSalah/Arabic-F5-TTS-v2](https://huggingface.co/IbrahimSalah/Arabic-F5-TTS-v2/tree/bd9ebf87d99c49789e6b41f3348d01c30b2444aa) | `bd9ebf87d99c49789e6b41f3348d01c30b2444aa` | `vocab.txt`, `F5TTS_Base_8_18.yaml`, `reference.wav`, model card |
| [charactr/vocos-mel-24khz](https://huggingface.co/charactr/vocos-mel-24khz/tree/0feb3fdd929bcd6649e0e7c5a688cf7dd012ef21) | `0feb3fdd929bcd6649e0e7c5a688cf7dd012ef21` | `config.yaml`, `pytorch_model.bin` (54,365,991 bytes), model card |
| [SWivid/F5-TTS code](https://github.com/SWivid/F5-TTS/tree/45868abaabd74aabf03cd673d6dd00cc9d9c01ae) | `45868abaabd74aabf03cd673d6dd00cc9d9c01ae` | Inference reference and MIT code license |

The companion downloader does not download the 5.65 GB Arabic base checkpoint: the requested Darja checkpoint replaces it. The actual Darja repository contains only its model card, Git attributes and final checkpoint; the mirror directory mentioned in the card is absent at this revision.

`scripts/prepare_darja_speech_assets.py` verifies every fetched file against pinned byte counts and SHA-256 values. It writes `companions-manifest.json` into the model directory, recording every source URL, original hash, derived-audio hash, conversion method and reference transcript. Model cards and the F5 code license are preserved in the model directory's `notices` folder.

## Licenses and attribution

- The Darja fine-tune declares Apache-2.0 in its model-card metadata. No standalone license file is supplied in that repository.
- The Arabic base declares `fair-noncommercial-research-license`; its [model card](https://huggingface.co/IbrahimSalah/Arabic-F5-TTS-v2/blob/bd9ebf87d99c49789e6b41f3348d01c30b2444aa/README.md) permits educational, research and personal noncommercial use and requires author permission for commercial use. It supplies no separate full license file.
- [Upstream F5 pretrained weights](https://huggingface.co/SWivid/F5-TTS) declare CC-BY-NC-4.0. The [F5 implementation](https://github.com/SWivid/F5-TTS/blob/45868abaabd74aabf03cd673d6dd00cc9d9c01ae/LICENSE) is MIT. The code license and weight license are distinct.
- [Vocos](https://huggingface.co/charactr/vocos-mel-24khz/blob/0feb3fdd929bcd6649e0e7c5a688cf7dd012ef21/README.md) declares MIT.
- The fine-tune's [Loubna](https://huggingface.co/datasets/oddadmix/arabic-audio-collection-algerian-loubna-stories), [Rawi](https://huggingface.co/datasets/oddadmix/arabic-audio-collection-algerian-rawi), and [Kahwa](https://huggingface.co/datasets/oddadmix/arabic-audio-collection-algerian-kahwa-postcast) training collections declare `other`; their cards say the original creators and channels retain rights to the source audio. No recordings from these datasets are downloaded by this integration.

The Apache metadata alone does not establish that inherited noncommercial restrictions or third-party voice rights have been cleared. Preserve these notices for the family's personal educational use; do not describe the model package as cleared for commercial redistribution. This document records the published terms rather than supplying new permission.

Credit: Kamel Touati for the Darja fine-tune; Ibrahim Salah for the Arabic base; SWivid and F5-TTS contributors for F5-TTS; Hubert Siuzdak / Charactr for Vocos.

## Published test reference

The Arabic base explicitly supplies `reference.wav` and demonstrates its use in its [linked inference notebook](https://colab.research.google.com/drive/1udTmXSarrw9upSVp3tV5xl0Ki-2bTnhU). The file is 6 seconds of PCM16 stereo audio at 44,100 Hz. Its original SHA-256 is `d6db1e038c67df75cdde9ad1e43ba05f660eebc9346a30617d9b2f3892a5b201`.

The notebook's reference transcript is stored verbatim in `reference.txt`. A derived `reference-24k-mono.wav` averages the channels and resamples to 24,000 Hz PCM16; the manifest records whether SciPy polyphase resampling or Python's `audioop` was used. The original is preserved unchanged. The transcript is publisher-supplied, not a fresh transcription or independent verification of its speaker.

This is an MSA example reference, not an Algiers-native voice claim. No separate speaker identity or speaker-consent declaration was found in the base repository or linked notebook. Do not treat its presence as a general voice-rights certificate. A family voice supplied by an adult who agrees to its use can provide a more appropriate personal reference. Do not substitute arbitrary YouTube or dataset recordings.

Official [F5 inference guidance](https://github.com/SWivid/F5-TTS/blob/45868abaabd74aabf03cd673d6dd00cc9d9c01ae/src/f5_tts/infer/README.md) calls for a short reference below 12 seconds, a matching transcript and some ending silence. The normal preprocessing path handles reference preparation; leaving the transcript blank invokes an extra ASR model, which is unnecessary for the supplied example.

## Text and quality checks

Use the custom 8-convolution/18-head architecture and published vocabulary; the stock F5 architecture is not interchangeable. Apply the Darja card's normalisation to synthesis input while retaining original display text. The existing curriculum has 289 text slots (180 cards, 36 phrases, 73 story lines). Story speaker labels should be handled as metadata rather than spoken dialogue. The unsupported character پ in the doll spelling has an attested alternate spelling بوبية already documented by the curriculum; use a synthesis alias without changing the child's displayed word.

Short words, French loans, unvocalised homographs and feminine endings require listening review. In particular, white and eggs share the displayed spelling بيض and need distinct pronunciation treatment. Generated clips should not be labelled native recordings or accepted solely because a file was produced.
