$out = "C:\docker\test-results"
docker run --rm -v "${out}:/out" -t score-gcc-test 2>&1 | Tee-Object -FilePath "$out\run.log"
pause