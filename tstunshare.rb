CLONE_NO=56
UNSHARE_NO = 272
CLONE_NEWNET=0x40000000

def unshare
  `ifconfig -a > x`
  syscall UNSHARE_NO, CLONE_NEWNET
  `echo "-------" >> x`
  `ifconfig -a >> x`
end

unshare
