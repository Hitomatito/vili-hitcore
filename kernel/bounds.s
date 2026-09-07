	.text
	.file	"bounds.c"
	.globl	main                            // -- Begin function main
	.p2align	2
	.type	main,@function
main:                                   // @main
// %bb.0:
	//APP

	.ascii	"->NR_PAGEFLAGS 22 __NR_PAGEFLAGS"
	//NO_APP
	//APP

	.ascii	"->MAX_NR_ZONES 2 __MAX_NR_ZONES"
	//NO_APP
	//APP

	.ascii	"->NR_CPUS_BITS 5 order_base_2(CONFIG_NR_CPUS)"
	//NO_APP
	//APP

	.ascii	"->SPINLOCK_SIZE 4 sizeof(spinlock_t)"
	//NO_APP
	mov	w0, wzr
	ret
.Lfunc_end0:
	.size	main, .Lfunc_end0-main
                                        // -- End function
	.ident	"Android (11967740, +pgo, +bolt, +lto, +mlgo, based on r522817) clang version 18.0.1 (https://android.googlesource.com/toolchain/llvm-project d8003a456d14a3deb8054cdaa529ffbf02d9b262)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
