# Score-Toolchain Docker

Rewrite of LiraNuna and Ppcasm toolchain builds

Original repository [here](https://github.com/ppcasm/score-sdk/tree/main/tools/score7/score-toolchain)

> ⚠️ **WARNING**
> **This project is experimental and low-level. You can permanently brick your
>  hardware if you misuse them. You assume all risk for anything you do with the tools
>  and information in this repository.**

## build image

`docker build .`

## test cross compiler

**Windows (PowerShell):**
```powershell
$out = "C:\docker\test-results" docker run --rm  -v "${out}:/out"  -t score-gcc-test 2>&1 |  Tee-Object  -FilePath "$out\run.log"
``` 
**macOS/Linux:**
```bash
OUT="$HOME/docker/test-results" mkdir -p "$OUT" docker run --rm -v "$OUT:/out" -t score-gcc-test 2>&1  |  tee  "$OUT/run.log"
```

## Thanks to
-   Bushing - (RIP) He was responsible for the hyperscan firmware being dumped originally, and a good source of valid information
-   LiraNuna - Support
-   Ppcasm - Head Engineer
-   Sunplus - They actually indirectly provided a lot of information and tools through other S+Core products, and at least made a very good effort to support open-source
-   Mattel - I like Barbie
-   MGA - I also like Bratz

## License

**MIT**
