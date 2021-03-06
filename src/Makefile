CC := gcc
CXX := g++
INCLUDEDIR = .
CFLAGS := -I$(INCLUDEDIR) -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -O2

all: asustrx addpattern untrx motorola-bin splitter3 binwalk
	make -C ./uncramfs/
	make -C ./uncramfs-lzma/
	make -C ./cramfs-2.x/
	make -C ./cramfsswap/
	make -C ./squashfs-2.1-r2/
	make -C ./squashfs-3.0/
	make -C ./squashfs-3.0-lzma-damn-small-variant/
	make -C ./wrt_vx_imgtool/
	make -C ./others/
	make -C ./crcalc/
	make -C ./webcomp-tools/

addpattern: addpattern.o
	$(CC) addpattern.o -o $@

untrx: untrx.o
	$(CXX) untrx.o -o $@

splitter3: splitter3.o
	$(CXX) splitter3.o -o $@

asustrx: asustrx.o
	$(CC) asustrx.o -o $@

motorola-bin: motorola-bin.o
	$(CC) motorola-bin.o -o $@

binwalk:
	(cd ./binwalk*/src && ./configure --disable-updates && make && cp binwalk ../../)

clean:
	rm -f *.o
	rm -f motorola-bin
	rm -f untrx
	rm -f asustrx
	rm -f addpattern
	rm -f splitter3
	rm -f binwalk
	make -C ./squashfs-2.1-r2/ clean
	make -C ./squashfs-3.0 clean
	make -C ./squashfs-3.0-lzma-damn-small-variant clean
	make -C ./cramfs-2.x clean
	make -C ./uncramfs clean
	make -C ./uncramfs-lzma clean
	make -C ./cramfsswap clean
	make -C ./wrt_vx_imgtool clean
	make -C ./others clean
	make -C ./crcalc clean
	make -C ./webcomp-tools clean
	make -C ./binwalk*/src/ cleanall
