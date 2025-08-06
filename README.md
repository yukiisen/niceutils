# NiceUtils :)

This is a rediculous projects I'm doing which is recreating some core cli tools in assembly because it feels nice ._.

# Current Utils:
- `cat`: no flags yet, basic usage only (read files or stdin)
- `cp`: no flags yet, copy files to dir or copy file to file and creates destination if it doesn't exist (file or dir)

# Next ones:
- `grep`
- `wc`
- `rm`
- `ls`
- `touch`
- `basename` (really just extract it from cp ._.)
- `find`
- `diff` (fancy, I'll die doing this)

# Notes:

Don't use those things for your daily life :)
and my cat is slightly faster than normal cat ._.

# Requirements:
Compiling this requires an assembler (I used `nasm` here, IDK about others), and a linker (`ld` or `mold` or `lld`)

To change which tools to use, check the `Makefile`
