# curl -LsSf https://astral.sh/uv/install.sh | sh
# sudo apt-get install binutils gcc file
uv run ./build.py && objdump -d temp.o && xxd out
chmod +x out
./out
