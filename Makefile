# TODO: Implement a way to keep this in sync with the source.
VARIANTS = default keychain eyes-only cheeks-only mouth-only

.PHONY: all
all: ${VARIANTS}

.PHONY:${VARIANTS}
${VARIANTS}:
	openscad \
  --enable lazy-union \
  --backend Manifold \
  -D 'VARIANT = "$@";' \
  -o 'bun-mascot.scad.$@.3mf' \
  bun-mascot.scad

.PHONY: clean
clean:
	rm -rf *.3mf
