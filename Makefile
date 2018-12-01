# Run PICO-8 cart.
run:
	@open \
		-n \
		-a PICO-8 \
		--args \
			-gif_scale 10 \
			-home $(shell pwd) \
			-run $(shell pwd)/carts/santa.p8
.PHONY: run
