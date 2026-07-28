.section .rodata
busybox:
  .asciz "/bin/busybox"
shell:
  .asciz "sh"
stage1:
  .asciz "/init-stage1"

.section .text
.global _start
.type _start, %function
_start:
  sub sp, sp, #32
  adr x0, busybox
  str x0, [sp, #0]
  adr x3, shell
  str x3, [sp, #8]
  adr x3, stage1
  str x3, [sp, #16]
  str xzr, [sp, #24]
  mov x1, sp
  mov x2, xzr
  mov x8, #221
  svc #0
  mov x0, #127
  mov x8, #93
  svc #0
.size _start, .-_start
