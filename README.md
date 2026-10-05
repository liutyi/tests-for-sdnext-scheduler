# tests-for-sdnext-scheduler
Automating scripts to schedule test images generation

## Example of script use

```
oliutyi@server7:~/tests-for-sdnext-scheduler$ ./run-test.sh server7 Qwen-Image-2.1 art46 qwen21-pruna-8step-lora
oliutyi@server7:~/tests-for-sdnext-scheduler$ ./run-test.sh --server server7 --model Qwen-Image-2.1 --test art46 --lora krea2-strange-reverie
oliutyi@server7:~/tests-for-sdnext-scheduler$ ./run-test.sh server7 Qwen-Image-2.1 art46        # no lora, prompts untouched

oliutyi@server7:~/tests-for-sdnext-scheduler$ ./run-test.sh server6 ERNIE-Image-Turbo couture-gpt2
▶ server: server6
▶ model:  ERNIE-Image-Turbo
▶ test:   couture-gpt2  (/home/oliutyi/tests-for-sdnext-scheduler/couture-tests/couture-gpt2.sh)

[QUEUE 01] A photorealistic high-fashion editorial portrait of Japanese female model, sharp elegant facial features, porcelain skin…
[QUEUE 02] A photorealistic high-fashion editorial portrait of a South Korean woman in her late 20s with a sharp jawline, porcelain…
[QUEUE 03] A photorealistic high-fashion editorial portrait of a Filipina woman in her late 20s, warm golden-brown skin, defined ch…
[QUEUE 04] A photorealistic high-fashion editorial portrait of an Indian female model with warm brown skin, defined cheekbones, exp…
[QUEUE 05] A photorealistic high-fashion editorial portrait of a Brazilian woman in her late 20s, sun-kissed skin, high cheekbones,…
[QUEUE 06] A photorealistic high-fashion editorial portrait of a Swedish woman in her late 20s, pale skin with a natural glow, ligh…
```

## Example test results
- https://wiki.liutyi.info/display/AI/liutyi+text2image+test+v1
- https://wiki.liutyi.info/display/AI/liutyi+text2image+test+v2
- https://wiki.liutyi.info/display/AI/liutyi+text2image+test+v3
