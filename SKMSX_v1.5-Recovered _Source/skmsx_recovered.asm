; SKMSX.COM recovered source
; SideKick for MSX 1 v1.5 - Ronivon C. Costa, 11/1993
;
; Reconstructed from the surviving SKMSX.COM binary.  This source assembles
; back to the original .COM image while naming MSX-DOS/BIOS-facing addresses
; and documenting the installer, hotkey loader, editor core, command handlers,
; and resident work area.
;
; Build with sjasmplus 1.24+:
;   sjasmplus skmsx_recovered.asm

    output "skmsx_rebuilt.com"
    org 0100h

; ---------------------------------------------------------------------------
; MSX-DOS / MSX BIOS work-area definitions
; ---------------------------------------------------------------------------
BDOS                 equ 0005h       ; MSX-DOS BDOS entry used by .COM files
BDOS_BASIC           equ 0F37Dh      ; Disk BASIC/BDOS entry in system area
DOS_COMMAND_TAIL     equ 0080h       ; CP/M style command tail: length + chars
DOS_HIMEM_MCB        equ 0F349h      ; MSX-DOS high-memory block chain pointer
VOICBQ               equ 0F9F5h      ; PSG voice queue B; fallback install marker
H_NMI                equ 0FDCCh      ; NMI hook opcode byte
H_NMI_ADDR           equ 0FDCDh      ; NMI hook target address

VDP_DATA_PORT        equ 098h
VDP_CONTROL_PORT     equ 099h
PPI_PORT_B           equ 0A9h
PPI_PORT_C           equ 0AAh

VRAM_RESIDENT_STORE  equ 1000h       ; VRAM slot used to keep resident editor
RESIDENT_STORE_SIZE  equ 0D80h
l0d2ah               equ 0D2Ah      ; spurious label emitted inside banner data
install_mode_flag    equ 8CFFh       ; 'I' install or 'U' uninstall flag

; ---------------------------------------------------------------------------
; Installer / uninstaller, loaded by MSX-DOS at 0100h.
; Parses /U, searches the DOS high-memory chain for space, stamps SKMSX into
; the chosen block, installs the hotkey hook, and prints the startup banner.
; ---------------------------------------------------------------------------

	di			;0100	f3 	. 
	ld hl,DOS_COMMAND_TAIL		;0101	21 80 00 	! . . 
	ld a,(hl)			;0104	7e 	~ 
	or a			;0105	b7 	. 
	ld a,049h		;0106	3e 49 	> I 
	ld (install_mode_flag),a		;0108	32 ff 8c 	2 . . 
	jr z,find_install_area		;010b	28 56 	( V 
	ld b,a			;010d	47 	G 
scan_command_tail:
	inc hl			;010e	23 	# 
	ld a,(hl)			;010f	7e 	~ 
	cp 02fh		;0110	fe 2f 	. / 
	jr z,parse_switch		;0112	28 04 	( . 
	djnz scan_command_tail		;0114	10 f8 	. . 
	jr find_install_area		;0116	18 4b 	. K 
parse_switch:
	inc hl			;0118	23 	# 
	ld a,(hl)			;0119	7e 	~ 
	and 05fh		;011a	e6 5f 	. _ 
	cp 055h		;011c	fe 55 	. U 
	jr nz,bad_parameter		;011e	20 05 	  . 
	ld (install_mode_flag),a		;0120	32 ff 8c 	2 . . 
	jr find_install_area		;0123	18 3e 	. > 
bad_parameter:
	ld de,msg_bad_parameter		;0125	11 2d 01 	. - . 
print_and_exit_bdos:
	ld c,009h		;0128	0e 09 	. . 
	jp BDOS		;012a	c3 05 00 	. . . 
msg_bad_parameter:
; DOS function 09h string: CR/LF "Parametro Invalido." CR/LF "$".
; The accented bytes are preserved exactly from the original binary.
	dec c			;012d	0d 	. 
	ld a,(bc)			;012e	0a 	. 
	ld d,b			;012f	50 	P 
	ld h,c			;0130	61 	a 
	ld (hl),d			;0131	72 	r 
	add a,e			;0132	83 	. 
	ld l,l			;0133	6d 	m 
	ld h,l			;0134	65 	e 
	ld (hl),h			;0135	74 	t 
	ld (hl),d			;0136	72 	r 
	ld l,a			;0137	6f 	o 
	jr nz,$+75		;0138	20 49 	  I 
	ld l,(hl)			;013a	6e 	n 
	halt			;013b	76 	v 
	and b			;013c	a0 	. 
	ld l,h			;013d	6c 	l 
	ld l,c			;013e	69 	i 
	ld h,h			;013f	64 	d 
	ld l,a			;0140	6f 	o 
	ld l,00dh		;0141	2e 0d 	. . 
	ld a,(bc)			;0143	0a 	. 
	inc h			;0144	24 	$ 
already_installed:
	ld de,msg_not_installed		;0145	11 4a 01 	. J . 
	jr print_and_exit_bdos		;0148	18 de 	. . 
msg_not_installed:
; DOS function 09h string: CR/LF "SKMSX nao Instalado." CR/LF "$".
	dec c			;014a	0d 	. 
	ld a,(bc)			;014b	0a 	. 
	ld d,e			;014c	53 	S 
	ld c,e			;014d	4b 	K 
	ld c,l			;014e	4d 	M 
	ld d,e			;014f	53 	S 
	ld e,b			;0150	58 	X 
	jr nz,install_or_uninstall_voice_queue		;0151	20 6e 	  n 
	or c			;0153	b1 	. 
	ld l,a			;0154	6f 	o 
	jr nz,$+75		;0155	20 49 	  I 
	ld l,(hl)			;0157	6e 	n 
	ld (hl),e			;0158	73 	s 
	ld (hl),h			;0159	74 	t 
	ld h,c			;015a	61 	a 
	ld l,h			;015b	6c 	l 
	ld h,c			;015c	61 	a 
	ld h,h			;015d	64 	d 
	ld l,a			;015e	6f 	o 
	ld l,00dh		;015f	2e 0d 	. . 
	ld a,(bc)			;0161	0a 	. 
	inc h			;0162	24 	$ 
find_install_area:
	ld hl,DOS_HIMEM_MCB		;0163	21 49 f3 	! I . 
	ld a,(hl)			;0166	7e 	~ 
	inc hl			;0167	23 	# 
	ld h,(hl)			;0168	66 	f 
	ld l,a			;0169	6f 	o 
scan_next_mcb:
	ld a,(hl)			;016a	7e 	~ 
	cp 048h		;016b	fe 48 	. H 
	jp nz,not_high_memory_block		;016d	c2 be 01 	. . . 
	inc hl			;0170	23 	# 
	ld a,(hl)			;0171	7e 	~ 
	cp 04dh		;0172	fe 4d 	. M 
	jp nz,not_high_memory_block		;0174	c2 be 01 	. . . 
	inc hl			;0177	23 	# 
	ld e,(hl)			;0178	5e 	^ 
	inc hl			;0179	23 	# 
	ld d,(hl)			;017a	56 	V 
	bit 7,d		;017b	cb 7a 	. z 
	jp z,check_candidate_block_size		;017d	ca 09 02 	. . . 
	res 7,d		;0180	cb ba 	. . 
	ld a,(install_mode_flag)		;0182	3a ff 8c 	: . . 
	cp 055h		;0185	fe 55 	. U 
	jp nz,advance_to_next_mcb		;0187	c2 28 02 	. ( . 
try_uninstall_from_mcb:
	inc hl			;018a	23 	# 
	ld a,(hl)			;018b	7e 	~ 
	cp 053h		;018c	fe 53 	. S 
	jr nz,l01a2h		;018e	20 12 	  . 
	inc hl			;0190	23 	# 
	ld a,(hl)			;0191	7e 	~ 
	cp 04bh		;0192	fe 4b 	. K 
	jr nz,l01a1h		;0194	20 0b 	  . 
	dec hl			;0196	2b 	+ 
	dec hl			;0197	2b 	+ 
	ld (hl),d			;0198	72 	r 
restore_nmi_and_reboot:
	ld a,0c9h		;0199	3e c9 	> . 
	ld (H_NMI),a		;019b	32 cc fd 	2 . . 
	jp 00000h		;019e	c3 00 00 	. . . 
l01a1h:
	dec hl			;01a1	2b 	+ 
l01a2h:
	dec hl			;01a2	2b 	+ 
	jp advance_to_next_mcb		;01a3	c3 28 02 	. ( . 
try_uninstall_from_voice_queue:
	ld a,(VOICBQ)		;01a6	3a f5 f9 	: . . 
	cp 053h		;01a9	fe 53 	. S 
	jr nz,already_installed		;01ab	20 98 	  . 
	ld a,(VOICBQ+1)		;01ad	3a f6 f9 	: . . 
	cp 04bh		;01b0	fe 4b 	. K 
	jr nz,already_installed		;01b2	20 91 	  . 
	ld a,020h		;01b4	3e 20 	>   
	ld (VOICBQ),a		;01b6	32 f5 f9 	2 . . 
	ld (VOICBQ+1),a		;01b9	32 f6 f9 	2 . . 
	jr restore_nmi_and_reboot		;01bc	18 db 	. . 
not_high_memory_block:
	ld a,(install_mode_flag)		;01be	3a ff 8c 	: . . 
install_or_uninstall_voice_queue:
	cp 055h		;01c1	fe 55 	. U 
	jr z,try_uninstall_from_voice_queue		;01c3	28 e1 	( . 
	ld de,msg_installing_voice_queue		;01c5	11 d8 01 	. . . 
	ld c,009h		;01c8	0e 09 	. . 
	call BDOS		;01ca	cd 05 00 	. . . 
	ld hl,VOICBQ		;01cd	21 f5 f9 	! . . 
	ld (hl),053h		;01d0	36 53 	6 S 
	inc hl			;01d2	23 	# 
	ld (hl),04bh		;01d3	36 4b 	6 K 
	inc hl			;01d5	23 	# 
	jr write_skmsx_signature		;01d6	18 5b 	. [ 
msg_installing_voice_queue:
; DOS function 09h string used by the low-memory fallback path:
; "No high Memory!" and "Instalando na fila musical B..."
	ld c,(hl)			;01d8	4e 	N 
	ld l,a			;01d9	6f 	o 
	jr nz,install_resident		;01da	20 68 	  h 
	ld l,c			;01dc	69 	i 
	ld h,a			;01dd	67 	g 
	ld l,b			;01de	68 	h 
	jr nz,mark_block_reserved		;01df	20 4d 	  M 
	ld h,l			;01e1	65 	e 
	ld l,l			;01e2	6d 	m 
	ld l,a			;01e3	6f 	o 
	ld (hl),d			;01e4	72 	r 
	ld a,c			;01e5	79 	y 
	ld hl,00a0dh		;01e6	21 0d 0a 	! . . 
	ld c,c			;01e9	49 	I 
	ld l,(hl)			;01ea	6e 	n 
	ld (hl),e			;01eb	73 	s 
	ld (hl),h			;01ec	74 	t 
	ld h,c			;01ed	61 	a 
	ld l,h			;01ee	6c 	l 
	ld h,c			;01ef	61 	a 
	ld l,(hl)			;01f0	6e 	n 
	ld h,h			;01f1	64 	d 
	ld l,a			;01f2	6f 	o 
	jr nz,l0263h		;01f3	20 6e 	  n 
	ld h,c			;01f5	61 	a 
	jr nz,$+104		;01f6	20 66 	  f 
	ld l,c			;01f8	69 	i 
	ld l,h			;01f9	6c 	l 
	ld h,c			;01fa	61 	a 
	jr nz,$+111		;01fb	20 6d 	  m 
	ld (hl),l			;01fd	75 	u 
	ld (hl),e			;01fe	73 	s 
	ld l,c			;01ff	69 	i 
	ld h,e			;0200	63 	c 
	ld h,c			;0201	61 	a 
	ld l,h			;0202	6c 	l 
	jr nz,$+68		;0203	20 42 	  B 
	ld l,02eh		;0205	2e 2e 	. . 
	ld l,024h		;0207	2e 24 	. $ 
check_candidate_block_size:
	ld a,(install_mode_flag)		;0209	3a ff 8c 	: . . 
	cp 055h		;020c	fe 55 	. U 
	jp z,try_uninstall_from_mcb		;020e	ca 8a 01 	. . . 
	push hl			;0211	e5 	. 
	push de			;0212	d5 	. 
	ld hl,resident_loader_end		;0213	21 e8 04 	! . . 
	ld bc,nmi_hook_entry		;0216	01 27 04 	. ' . 
	xor a			;0219	af 	. 
	sbc hl,bc		;021a	ed 42 	. B 
	ld bc,00007h		;021c	01 07 00 	. . . 
	add hl,bc			;021f	09 	. 
	ex de,hl			;0220	eb 	. 
	xor a			;0221	af 	. 
	sbc hl,de		;0222	ed 52 	. R 
	jr nc,candidate_block_ok		;0224	30 07 	0 . 
	pop de			;0226	d1 	. 
	pop hl			;0227	e1 	. 
advance_to_next_mcb:
	inc hl			;0228	23 	# 
	add hl,de			;0229	19 	. 
	jp scan_next_mcb		;022a	c3 6a 01 	. j . 
candidate_block_ok:
	pop de			;022d	d1 	. 
mark_block_reserved:
	pop hl			;022e	e1 	. 
	set 7,d		;022f	cb fa 	. . 
	ld (hl),d			;0231	72 	r 
	inc hl			;0232	23 	# 
write_skmsx_signature:
	ld (hl),053h		;0233	36 53 	6 S 
	inc hl			;0235	23 	# 
	ld (hl),04bh		;0236	36 4b 	6 K 
	inc hl			;0238	23 	# 
	ld (hl),04dh		;0239	36 4d 	6 M 
	inc hl			;023b	23 	# 
	ld (hl),053h		;023c	36 53 	6 S 
	inc hl			;023e	23 	# 
	ld (hl),058h		;023f	36 58 	6 X 
	inc hl			;0241	23 	# 
	ld (hl),000h		;0242	36 00 	6 . 
install_resident:
	inc hl			;0244	23 	# 
	push hl			;0245	e5 	. 
	ld de,nmi_hook_entry		;0246	11 27 04 	. ' . 
	ld bc,resident_loader_end		;0249	01 e8 04 	. . . 
	call sub_03fch		;024c	cd fc 03 	. . . 
	pop hl			;024f	e1 	. 
	push hl			;0250	e5 	. 
	ld de,nmi_hook_entry		;0251	11 27 04 	. ' . 
	ex de,hl			;0254	eb 	. 
	ld bc,000c1h		;0255	01 c1 00 	. . . 
	ldir		;0258	ed b0 	. . 
	ld hl,resident_image		;025a	21 04 05 	! . . 
	ld de,VRAM_RESIDENT_STORE		;025d	11 00 10 	. . . 
	ld bc,RESIDENT_STORE_SIZE		;0260	01 80 0d 	. . . 
l0263h:
	call sub_0419h		;0263	cd 19 04 	. . . 
	ld hl,0f87fh		;0266	21 7f f8 	!  . 
	ld de,0f880h		;0269	11 80 f8 	. . . 
	ld bc,0009fh		;026c	01 9f 00 	. . . 
	ld (hl),020h		;026f	36 20 	6   
	ldir		;0271	ed b0 	. . 
	ld de,voice_queue_signature		;0273	11 8b 02 	. . . 
	ld hl,0f87fh		;0276	21 7f f8 	!  . 
	ld b,00ah		;0279	06 0a 	. . 
copy_name_to_voice_queue:
	ld a,(de)			;027b	1a 	. 
	ld (hl),a			;027c	77 	w 
	inc hl			;027d	23 	# 
	ld (hl),000h		;027e	36 00 	6 . 
	push bc			;0280	c5 	. 
	ld bc,0000fh		;0281	01 0f 00 	. . . 
	add hl,bc			;0284	09 	. 
	inc de			;0285	13 	. 
	pop bc			;0286	c1 	. 
	djnz copy_name_to_voice_queue		;0287	10 f2 	. . 
	jr $+12		;0289	18 0a 	. . 
voice_queue_signature:
; Bytes written into VOICBQ as a compact installed marker.
	ret			;028b	c9 	. 
	jp z,0cccbh		;028c	ca cb cc 	. . . 
	call 0c0bfh		;028f	cd bf c0 	. . . 
	pop bc			;0292	c1 	. 
	jp nz,011c3h		;0293	c2 c3 11 	. . . 
	xor b			;0296	a8 	. 
	ld (bc),a			;0297	02 	. 
	ld c,009h		;0298	0e 09 	. . 
	call BDOS		;029a	cd 05 00 	. . . 
	pop hl			;029d	e1 	. 
	ld (H_NMI_ADDR),hl		;029e	22 cd fd 	" . . 
	ld a,0c3h		;02a1	3e c3 	> . 
	ld (H_NMI),a		;02a3	32 cc fd 	2 . . 
	ei			;02a6	fb 	. 
	ret			;02a7	c9 	. 
; DOS function 09h startup banner shown after installation.
	dec c			;02a8	0d 	. 
	ld a,(bc)			;02a9	0a 	. 
	ld a,(bc)			;02aa	0a 	. 
	ld hl,(02a2ah)		;02ab	2a 2a 2a 	* * * 
	ld hl,(02a2ah)		;02ae	2a 2a 2a 	* * * 
	ld hl,(02a2ah)		;02b1	2a 2a 2a 	* * * 
	ld hl,(02a2ah)		;02b4	2a 2a 2a 	* * * 
	ld hl,(02a2ah)		;02b7	2a 2a 2a 	* * * 
	ld hl,(02a2ah)		;02ba	2a 2a 2a 	* * * 
	ld hl,(02a2ah)		;02bd	2a 2a 2a 	* * * 
	ld hl,(02a2ah)		;02c0	2a 2a 2a 	* * * 
	ld hl,(l0d2ah)		;02c3	2a 2a 0d 	* * . 
	ld a,(bc)			;02c6	0a 	. 
	ld hl,(02020h)		;02c7	2a 20 20 	*     
	jr nz,l02ech		;02ca	20 20 	    
	jr nz,l02eeh		;02cc	20 20 	    
	jr nz,$+34		;02ce	20 20 	    
	jr nz,l02f2h		;02d0	20 20 	    
	jr nz,$+34		;02d2	20 20 	    
	jr nz,l02f6h		;02d4	20 20 	    
	jr nz,$+34		;02d6	20 20 	    
	jr nz,$+34		;02d8	20 20 	    
	jr nz,$+34		;02da	20 20 	    
	jr nz,l02feh		;02dc	20 20 	    
	jr nz,$+34		;02de	20 20 	    
	ld hl,(00a0dh)		;02e0	2a 0d 0a 	* . . 
	ld hl,(02020h)		;02e3	2a 20 20 	*     
	jr nz,l033bh		;02e6	20 53 	  S 
	ld l,c			;02e8	69 	i 
	ld h,h			;02e9	64 	d 
	ld h,l			;02ea	65 	e 
	ld c,e			;02eb	4b 	K 
l02ech:
	ld l,c			;02ec	69 	i 
	ld h,e			;02ed	63 	c 
l02eeh:
	ld l,e			;02ee	6b 	k 
	jr nz,$+104		;02ef	20 66 	  f 
	ld l,a			;02f1	6f 	o 
l02f2h:
	ld (hl),d			;02f2	72 	r 
	jr nz,l0342h		;02f3	20 4d 	  M 
	ld d,e			;02f5	53 	S 
l02f6h:
	ld e,b			;02f6	58 	X 
	jr nz,$+51		;02f7	20 31 	  1 
	jr nz,l031bh		;02f9	20 20 	    
	jr nz,l0327h		;02fb	20 2a 	  * 
	dec c			;02fd	0d 	. 
l02feh:
	ld a,(bc)			;02fe	0a 	. 
	ld hl,(05620h)		;02ff	2a 20 56 	*   V 
	ld h,l			;0302	65 	e 
	ld (hl),d			;0303	72 	r 
	ld (hl),e			;0304	73 	s 
	or c			;0305	b1 	. 
	ld l,a			;0306	6f 	o 
	jr nz,l033ah		;0307	20 31 	  1 
	ld l,035h		;0309	2e 35 	. 5 
	jr nz,l032dh		;030b	20 20 	    
	dec l			;030d	2d 	- 
	jr nz,l0330h		;030e	20 20 	    
	ld sp,02f31h		;0310	31 31 2f 	1 1 / 
	ld sp,03939h		;0313	31 39 39 	1 9 9 
	inc sp			;0316	33 	3 
	jr nz,l0343h		;0317	20 2a 	  * 
	dec c			;0319	0d 	. 
	ld a,(bc)			;031a	0a 	. 
l031bh:
	ld hl,(02020h)		;031b	2a 20 20 	*     
	jr z,$+101		;031e	28 63 	( c 
	add hl,hl			;0320	29 	) 
	jr nz,$+84		;0321	20 52 	  R 
	ld l,a			;0323	6f 	o 
	ld l,(hl)			;0324	6e 	n 
	ld l,c			;0325	69 	i 
	halt			;0326	76 	v 
l0327h:
	ld l,a			;0327	6f 	o 
	ld l,(hl)			;0328	6e 	n 
	jr nz,$+69		;0329	20 43 	  C 
	ld l,020h		;032b	2e 20 	.   
l032dh:
	ld b,e			;032d	43 	C 
	ld l,a			;032e	6f 	o 
	ld (hl),e			;032f	73 	s 
l0330h:
	ld (hl),h			;0330	74 	t 
	ld h,c			;0331	61 	a 
	jr nz,$+34		;0332	20 20 	    
	ld hl,(00a0dh)		;0334	2a 0d 0a 	* . . 
	ld hl,(02d20h)		;0337	2a 20 2d 	*   - 
l033ah:
	dec l			;033a	2d 	- 
l033bh:
	dec l			;033b	2d 	- 
	dec l			;033c	2d 	- 
	dec l			;033d	2d 	- 
	dec l			;033e	2d 	- 
	dec l			;033f	2d 	- 
	dec l			;0340	2d 	- 
	dec l			;0341	2d 	- 
l0342h:
	dec l			;0342	2d 	- 
l0343h:
	dec l			;0343	2d 	- 
	dec l			;0344	2d 	- 
	dec l			;0345	2d 	- 
	dec l			;0346	2d 	- 
	dec l			;0347	2d 	- 
	dec l			;0348	2d 	- 
	dec l			;0349	2d 	- 
	dec l			;034a	2d 	- 
	dec l			;034b	2d 	- 
	dec l			;034c	2d 	- 
	dec l			;034d	2d 	- 
	dec l			;034e	2d 	- 
	jr nz,l037bh		;034f	20 2a 	  * 
	dec c			;0351	0d 	. 
	ld a,(bc)			;0352	0a 	. 
	ld hl,(02020h)		;0353	2a 20 20 	*     
	jr nz,l0378h		;0356	20 20 	    
	jr nz,l037ah		;0358	20 20 	    
	jr nz,l037ch		;035a	20 20 	    
	jr nz,l037eh		;035c	20 20 	    
	jr nz,l0380h		;035e	20 20 	    
	jr nz,l0382h		;0360	20 20 	    
	jr nz,l0384h		;0362	20 20 	    
	jr nz,l0386h		;0364	20 20 	    
	jr nz,l0388h		;0366	20 20 	    
	jr nz,$+34		;0368	20 20 	    
	jr nz,$+34		;036a	20 20 	    
	ld hl,(00a0dh)		;036c	2a 0d 0a 	* . . 
	ld hl,(02020h)		;036f	2a 20 20 	*     
	jr nz,l0394h		;0372	20 20 	    
	jr nz,copy_ram_from_vram		;0374	20 20 	    
	jr nz,l03c8h		;0376	20 50 	  P 
l0378h:
	ld d,d			;0378	52 	R 
	ld b,l			;0379	45 	E 
l037ah:
	ld d,e			;037a	53 	S 
l037bh:
	ld d,e			;037b	53 	S 
l037ch:
	ld c,c			;037c	49 	I 
	ld c,a			;037d	4f 	O 
l037eh:
	ld c,(hl)			;037e	4e 	N 
	ld b,l			;037f	45 	E 
l0380h:
	jr nz,l03a2h		;0380	20 20 	    
l0382h:
	jr nz,l03a4h		;0382	20 20 	    
l0384h:
	jr nz,$+34		;0384	20 20 	    
l0386h:
	jr nz,$+34		;0386	20 20 	    
l0388h:
	ld hl,(00a0dh)		;0388	2a 0d 0a 	* . . 
	ld hl,(02020h)		;038b	2a 20 20 	*     
	jr nz,l03b0h		;038e	20 20 	    
	jr nz,$+69		;0390	20 43 	  C 
	ld c,a			;0392	4f 	O 
	ld c,(hl)			;0393	4e 	N 
l0394h:
	ld d,h			;0394	54 	T 
	ld d,d			;0395	52 	R 
copy_ram_from_vram:
	ld c,a			;0396	4f 	O 
	ld c,h			;0397	4c 	L 
l0398h:
	dec hl			;0398	2b 	+ 
	ld d,e			;0399	53 	S 
	ld c,b			;039a	48 	H 
	ld c,c			;039b	49 	I 
	ld b,(hl)			;039c	46 	F 
	ld d,h			;039d	54 	T 
	jr nz,l03c0h		;039e	20 20 	    
	jr nz,$+34		;03a0	20 20 	    
l03a2h:
	jr nz,$+34		;03a2	20 20 	    
l03a4h:
	ld hl,(00a0dh)		;03a4	2a 0d 0a 	* . . 
	ld hl,(02020h)		;03a7	2a 20 20 	*     
	ld d,b			;03aa	50 	P 
	ld b,c			;03ab	41 	A 
	ld d,d			;03ac	52 	R 
	ld b,c			;03ad	41 	A 
l03aeh:
	jr nz,l03f1h		;03ae	20 41 	  A 
l03b0h:
	ld b,e			;03b0	43 	C 
	ld b,l			;03b1	45 	E 
	ld d,e			;03b2	53 	S 
	ld d,e			;03b3	53 	S 
	ld b,c			;03b4	41 	A 
l03b5h:
	ld d,d			;03b5	52 	R 
	jr nz,l0407h		;03b6	20 4f 	  O 
	jr nz,l040dh		;03b8	20 53 	  S 
	ld c,e			;03ba	4b 	K 
	ld c,l			;03bb	4d 	M 
l03bch:
	ld d,e			;03bc	53 	S 
	ld e,b			;03bd	58 	X 
	jr nz,$+34		;03be	20 20 	    
l03c0h:
	ld hl,(00a0dh)		;03c0	2a 0d 0a 	* . . 
	ld hl,(02020h)		;03c3	2a 20 20 	*     
	jr nz,relocation_table		;03c6	20 20 	    
l03c8h:
	jr nz,$+34		;03c8	20 20 	    
l03cah:
	jr nz,$+34		;03ca	20 20 	    
	jr nz,l03eeh		;03cc	20 20 	    
	jr nz,$+34		;03ce	20 20 	    
	jr nz,$+34		;03d0	20 20 	    
	jr nz,l03f4h		;03d2	20 20 	    
	jr nz,$+34		;03d4	20 20 	    
	jr nz,$+34		;03d6	20 20 	    
	jr nz,l03fah		;03d8	20 20 	    
	jr nz,sub_03fch		;03da	20 20 	    
	ld hl,(00a0dh)		;03dc	2a 0d 0a 	* . . 
	ld hl,(02a2ah)		;03df	2a 2a 2a 	* * * 
	ld hl,(02a2ah)		;03e2	2a 2a 2a 	* * * 
	ld hl,(02a2ah)		;03e5	2a 2a 2a 	* * * 
relocation_table:
	ld hl,(02a2ah)		;03e8	2a 2a 2a 	* * * 
	ld hl,(02a2ah)		;03eb	2a 2a 2a 	* * * 
l03eeh:
	ld hl,(02a2ah)		;03ee	2a 2a 2a 	* * * 
l03f1h:
	ld hl,(02a2ah)		;03f1	2a 2a 2a 	* * * 
l03f4h:
	ld hl,(02a2ah)		;03f4	2a 2a 2a 	* * * 
	ld hl,(l0d2ah)		;03f7	2a 2a 0d 	* * . 
l03fah:
	ld a,(bc)			;03fa	0a 	. 
	inc h			;03fb	24 	$ 
sub_03fch:
	xor a			;03fc	af 	. 
	sbc hl,de		;03fd	ed 52 	. R 
	push bc			;03ff	c5 	. 
	ld b,h			;0400	44 	D 
	ld c,l			;0401	4d 	M 
	pop hl			;0402	e1 	. 
l0403h:
	ld e,(hl)			;0403	5e 	^ 
	inc hl			;0404	23 	# 
	ld d,(hl)			;0405	56 	V 
	inc hl			;0406	23 	# 
l0407h:
	ld a,e			;0407	7b 	{ 
	or d			;0408	b2 	. 
	ret z			;0409	c8 	. 
	push hl			;040a	e5 	. 
	ex de,hl			;040b	eb 	. 
	ld e,(hl)			;040c	5e 	^ 
l040dh:
	inc hl			;040d	23 	# 
	ld d,(hl)			;040e	56 	V 
	dec hl			;040f	2b 	+ 
	ex de,hl			;0410	eb 	. 
	add hl,bc			;0411	09 	. 
	ex de,hl			;0412	eb 	. 
	ld (hl),e			;0413	73 	s 
	inc hl			;0414	23 	# 
	ld (hl),d			;0415	72 	r 
	pop hl			;0416	e1 	. 
	jr l0403h		;0417	18 ea 	. . 
sub_0419h:
	ex de,hl			;0419	eb 	. 
	call sub_04c3h		;041a	cd c3 04 	. . . 
l041dh:
	ld a,(de)			;041d	1a 	. 
	out (VDP_DATA_PORT),a		;041e	d3 98 	. . 
	inc de			;0420	13 	. 
	dec bc			;0421	0b 	. 
	ld a,c			;0422	79 	y 
	or b			;0423	b0 	. 
	jr nz,l041dh		;0424	20 f7 	  . 
	ret			;0426	c9 	. 
nmi_hook_entry:
	cp 030h		;0427	fe 30 	. 0 
	ret nz			;0429	c0 	. 
	di			;042a	f3 	. 
	in a,(PPI_PORT_C)		;042b	db aa 	. . 
	and 0f0h		;042d	e6 f0 	. . 
	or 006h		;042f	f6 06 	. . 
	out (PPI_PORT_C),a		;0431	d3 aa 	. . 
	in a,(PPI_PORT_B)		;0433	db a9 	. . 
	bit 1,a		;0435	cb 4f 	. O 
	jr z,l043dh		;0437	28 04 	( . 
	ld a,030h		;0439	3e 30 	> 0 
	ei			;043b	fb 	. 
	ret			;043c	c9 	. 
l043dh:
	push bc			;043d	c5 	. 
	push de			;043e	d5 	. 
	push hl			;043f	e5 	. 
	push ix		;0440	dd e5 	. . 
	push iy		;0442	fd e5 	. . 
	exx			;0444	d9 	. 
	push bc			;0445	c5 	. 
	push de			;0446	d5 	. 
	push hl			;0447	e5 	. 
	ld a,0c9h		;0448	3e c9 	> . 
	ld (H_NMI),a		;044a	32 cc fd 	2 . . 
	ld hl,00000h		;044d	21 00 00 	! . . 
	ld de,l03cah		;0450	11 ca 03 	. . . 
	ld bc,l03c0h		;0453	01 c0 03 	. . . 
	call sub_0496h		;0456	cd 96 04 	. . . 
	ld hl,(0f3dch)		;0459	2a dc f3 	* . . 
	ld (l0494h),hl		;045c	22 94 04 	" . . 
	call sub_04a6h		;045f	cd a6 04 	. . . 
	ei			;0462	fb 	. 
	call 08000h		;0463	cd 00 80 	. . . 
	di			;0466	f3 	. 
	call sub_04a6h		;0467	cd a6 04 	. . . 
	ld hl,l03cah		;046a	21 ca 03 	! . . 
	ld de,00000h		;046d	11 00 00 	. . . 
	ld bc,l03c0h		;0470	01 c0 03 	. . . 
	call sub_0496h		;0473	cd 96 04 	. . . 
	ld hl,(l0494h)		;0476	2a 94 04 	* . . 
	ld (0f3dch),hl		;0479	22 dc f3 	" . . 
	ld a,0c3h		;047c	3e c3 	> . 
	ld (H_NMI),a		;047e	32 cc fd 	2 . . 
	pop hl			;0481	e1 	. 
	pop de			;0482	d1 	. 
	pop bc			;0483	c1 	. 
	exx			;0484	d9 	. 
	pop iy		;0485	fd e1 	. . 
	pop ix		;0487	dd e1 	. . 
	pop hl			;0489	e1 	. 
	pop de			;048a	d1 	. 
	pop bc			;048b	c1 	. 
	ld a,031h		;048c	3e 31 	> 1 
	ei			;048e	fb 	. 
	ret			;048f	c9 	. 
	ret			;0490	c9 	. 
	ret			;0491	c9 	. 
	ret			;0492	c9 	. 
	ret			;0493	c9 	. 
l0494h:
	nop			;0494	00 	. 
	nop			;0495	00 	. 
sub_0496h:
	call sub_04e0h		;0496	cd e0 04 	. . . 
	ex de,hl			;0499	eb 	. 
	call sub_04d6h		;049a	cd d6 04 	. . . 
	ex de,hl			;049d	eb 	. 
	inc hl			;049e	23 	# 
	inc de			;049f	13 	. 
	dec bc			;04a0	0b 	. 
	ld a,b			;04a1	78 	x 
	or c			;04a2	b1 	. 
	jr nz,sub_0496h		;04a3	20 f1 	  . 
	ret			;04a5	c9 	. 
sub_04a6h:
	ld hl,08000h		;04a6	21 00 80 	! . . 
	ld de,VRAM_RESIDENT_STORE		;04a9	11 00 10 	. . . 
	ld bc,02fa8h		;04ac	01 a8 2f 	. . / 
l04afh:
	ld a,(hl)			;04af	7e 	~ 
	push af			;04b0	f5 	. 
	ex de,hl			;04b1	eb 	. 
	call sub_04e0h		;04b2	cd e0 04 	. . . 
	ld (de),a			;04b5	12 	. 
	pop af			;04b6	f1 	. 
	call sub_04d6h		;04b7	cd d6 04 	. . . 
	ex de,hl			;04ba	eb 	. 
	inc hl			;04bb	23 	# 
	inc de			;04bc	13 	. 
	dec bc			;04bd	0b 	. 
	ld a,b			;04be	78 	x 
	or c			;04bf	b1 	. 
	jr nz,l04afh		;04c0	20 ed 	  . 
	ret			;04c2	c9 	. 
sub_04c3h:
	ld a,l			;04c3	7d 	} 
	out (VDP_CONTROL_PORT),a		;04c4	d3 99 	. . 
	ld a,h			;04c6	7c 	| 
	and 03fh		;04c7	e6 3f 	. ? 
	or 040h		;04c9	f6 40 	. @ 
l04cbh:
	out (VDP_CONTROL_PORT),a		;04cb	d3 99 	. . 
	ret			;04cd	c9 	. 
sub_04ceh:
	ld a,l			;04ce	7d 	} 
	out (VDP_CONTROL_PORT),a		;04cf	d3 99 	. . 
	ld a,h			;04d1	7c 	| 
	and 03fh		;04d2	e6 3f 	. ? 
	jr l04cbh		;04d4	18 f5 	. . 
sub_04d6h:
	push af			;04d6	f5 	. 
	call sub_04c3h		;04d7	cd c3 04 	. . . 
	ex (sp),hl			;04da	e3 	. 
	ex (sp),hl			;04db	e3 	. 
	pop af			;04dc	f1 	. 
	out (VDP_DATA_PORT),a		;04dd	d3 98 	. . 
	ret			;04df	c9 	. 
sub_04e0h:
	call sub_04ceh		;04e0	cd ce 04 	. . . 
	ex (sp),hl			;04e3	e3 	. 
	ex (sp),hl			;04e4	e3 	. 
	in a,(VDP_DATA_PORT)		;04e5	db 98 	. . 
	ret			;04e7	c9 	. 
resident_loader_end:
; Word table consumed by relocate_pointer_table.  Each entry points inside the
; copied hotkey stub and is adjusted after the stub is moved into high memory.
	ld d,a			;04e8	57 	W 
	inc b			;04e9	04 	. 
	ld e,l			;04ea	5d 	] 
	inc b			;04eb	04 	. 
	ld h,b			;04ec	60 	` 
	inc b			;04ed	04 	. 
	ld l,b			;04ee	68 	h 
	inc b			;04ef	04 	. 
	ld (hl),h			;04f0	74 	t 
	inc b			;04f1	04 	. 
	ld (hl),a			;04f2	77 	w 
	inc b			;04f3	04 	. 
	sub b			;04f4	90 	. 
	inc b			;04f5	04 	. 
	sub a			;04f6	97 	. 
	inc b			;04f7	04 	. 
	sbc a,e			;04f8	9b 	. 
	inc b			;04f9	04 	. 
	or e			;04fa	b3 	. 
	inc b			;04fb	04 	. 
	cp b			;04fc	b8 	. 
	inc b			;04fd	04 	. 
	ret c			;04fe	d8 	. 
	inc b			;04ff	04 	. 
	pop hl			;0500	e1 	. 
	inc b			;0501	04 	. 
	nop			;0502	00 	. 
	nop			;0503	00 	. 

; ---------------------------------------------------------------------------
; Resident editor image.
; Stored here in the .COM image, but assembled with runtime addresses at 8000h.
; ---------------------------------------------------------------------------
resident_image:
    phase 8000h

editor_start:
	call clear_editor_screen		;8000	cd 15 89 	. . . 
	call init_editor_state		;8003	cd 2e 86 	. . . 
editor_loop:
	call redraw_screen		;8006	cd ff 85 	. . . 
	call draw_status_area		;8009	cd c2 89 	. . . 
	call draw_block_status		;800c	cd 68 8c 	. h . 
	call read_key		;800f	cd 7a 86 	. z . 
dispatch_key:
	ld (last_key),a		;8012	32 00 8d 	2 . . 
	cp 01bh		;8015	fe 1b 	. . 
	jp z,exit_editor		;8017	ca f9 86 	. . . 
	cp 07fh		;801a	fe 7f 	.  
	jp z,l8590h		;801c	ca 90 85 	. . . 
	cp 0c9h		;801f	fe c9 	. . 
	jp z,command_search		;8021	ca a5 88 	. . . 
	cp 0cah		;8024	fe ca 	. . 
	jp z,command_save_or_mark_1		;8026	ca 27 89 	. ' . 
	cp 0cbh		;8029	fe cb 	. . 
	jp z,command_save_or_mark_2		;802b	ca 48 89 	. H . 
	cp 0cch		;802e	fe cc 	. . 
	jp z,command_cut_block		;8030	ca 9a 8a 	. . . 
	cp 0cdh		;8033	fe cd 	. . 
	jp z,command_mark_block_end		;8035	ca bb 8a 	. . . 
	cp 0bfh		;8038	fe bf 	. . 
	jp z,command_comment_line		;803a	ca c7 8b 	. . . 
	cp 0c0h		;803d	fe c0 	. . 
	jp z,command_uncomment_line		;803f	ca d0 8b 	. . . 
	cp 0c1h		;8042	fe c1 	. . 
	jp z,command_insert_block_space		;8044	ca fa 8b 	. . . 
	cp 0c2h		;8047	fe c2 	. . 
	jp z,command_mark_block_start		;8049	ca ad 8a 	. . . 
	cp 0c3h		;804c	fe c3 	. . 
	jp z,command_paste_block		;804e	ca e2 8a 	. . . 
	cp 020h		;8051	fe 20 	.   
	jr nc,insert_printable_key		;8053	30 32 	0 2 
	cp 00dh		;8055	fe 0d 	. . 
	jp z,l8290h		;8057	ca 90 82 	. . . 
	cp 008h		;805a	fe 08 	. . 
	jp z,l82f4h		;805c	ca f4 82 	. . . 
	cp 012h		;805f	fe 12 	. . 
	jp z,l82e1h		;8061	ca e1 82 	. . . 
	cp 01dh		;8064	fe 1d 	. . 
	jp z,l840bh		;8066	ca 0b 84 	. . . 
	cp 01ch		;8069	fe 1c 	. . 
	jp z,l8514h		;806b	ca 14 85 	. . . 
	cp 01eh		;806e	fe 1e 	. . 
	jp z,l8369h		;8070	ca 69 83 	. i . 
	cp 01fh		;8073	fe 1f 	. . 
	jp z,l83d9h		;8075	ca d9 83 	. . . 
	cp 00bh		;8078	fe 0b 	. . 
	jp z,command_toggle_case_mode		;807a	ca c2 8b 	. . . 
	cp 00ch		;807d	fe 0c 	. . 
	jp z,command_toggle_insert_mode		;807f	ca b6 8b 	. . . 
	cp 009h		;8082	fe 09 	. . 
	jp nz,editor_loop		;8084	c2 06 80 	. . . 
insert_printable_key:
	call ensure_space_for_insert		;8087	cd c9 81 	. . . 
	jp nc,editor_start		;808a	d2 00 80 	. . . 
	call advance_cursor_after_insert		;808d	cd 62 82 	. b . 
	or a			;8090	b7 	. 
	jr nz,l80a6h		;8091	20 13 	  . 
	ld hl,(screen_cursor_ptr)		;8093	2a e2 8c 	* . . 
	dec hl			;8096	2b 	+ 
	ld a,(last_key)		;8097	3a 00 8d 	: . . 
	call poke_char_to_screen_line		;809a	cd e7 86 	. . . 
	call 08240h		;809d	cd 40 82 	. @ . 
	call append_key_to_buffer		;80a0	cd ac 80 	. . . 
	jp editor_loop		;80a3	c3 06 80 	. . . 
l80a6h:
	call append_key_to_buffer		;80a6	cd ac 80 	. . . 
	jp editor_start		;80a9	c3 00 80 	. . . 
append_key_to_buffer:
	ld hl,(edit_ptr)		;80ac	2a de 8c 	* . . 
	ld a,(last_key)		;80af	3a 00 8d 	: . . 
	ld (hl),a			;80b2	77 	w 
	inc hl			;80b3	23 	# 
	ld (edit_ptr),hl		;80b4	22 de 8c 	" . . 
	ret			;80b7	c9 	. 
move_edit_ptr_back_one_char:
	push af			;80b8	f5 	. 
	ld hl,(edit_ptr)		;80b9	2a de 8c 	* . . 
	dec hl			;80bc	2b 	+ 
	ld a,(hl)			;80bd	7e 	~ 
	cp 00ah		;80be	fe 0a 	. . 
	jr nz,l80c3h		;80c0	20 01 	  . 
	dec hl			;80c2	2b 	+ 
l80c3h:
	ld (edit_ptr),hl		;80c3	22 de 8c 	" . . 
	pop af			;80c6	f1 	. 
	ret			;80c7	c9 	. 
compare_de_with_text_end:
	ld de,(text_end_ptr)		;80c8	ed 5b e6 8c 	. [ . . 
	call compare_hl_de		;80cc	cd ce 86 	. . . 
	ret			;80cf	c9 	. 
compare_de_with_text_limit:
	ld de,text_buffer_start		;80d0	11 7f 8d 	.  . 
	call compare_hl_de		;80d3	cd ce 86 	. . . 
	ret			;80d6	c9 	. 
l80d7h:
	ld a,(hl)			;80d7	7e 	~ 
	cp 01ah		;80d8	fe 1a 	. . 
	jr z,l80e1h		;80da	28 05 	( . 
	inc hl			;80dc	23 	# 
	cp 00ah		;80dd	fe 0a 	. . 
	jr nz,l80d7h		;80df	20 f6 	  . 
l80e1h:
	ld (line_start_ptr),hl		;80e1	22 ee 8c 	" . . 
	ret			;80e4	c9 	. 
find_previous_line:
	call find_line_start_backward		;80e5	cd f0 80 	. . . 
	dec hl			;80e8	2b 	+ 
	call find_line_start_backward		;80e9	cd f0 80 	. . . 
	ld (line_start_ptr),hl		;80ec	22 ee 8c 	" . . 
	ret			;80ef	c9 	. 
find_line_start_backward:
	dec hl			;80f0	2b 	+ 
	ld a,(hl)			;80f1	7e 	~ 
	cp 00ah		;80f2	fe 0a 	. . 
	jr nz,find_line_start_backward		;80f4	20 fa 	  . 
	inc hl			;80f6	23 	# 
	ret			;80f7	c9 	. 
scan_visible_line_start:
	ld de,00000h		;80f8	11 00 00 	. . . 
	ld hl,(line_start_ptr)		;80fb	2a ee 8c 	* . . 
l80feh:
	ld (visible_line_column),de		;80fe	ed 53 ea 8c 	. S . . 
	ld (visible_line_ptr),hl		;8102	22 f0 8c 	" . . 
	ld hl,(window_left_column)		;8105	2a e8 8c 	* . . 
	call compare_hl_de		;8108	cd ce 86 	. . . 
	ret z			;810b	c8 	. 
	ld hl,(visible_line_ptr)		;810c	2a f0 8c 	* . . 
	ld b,00ah		;810f	06 0a 	. . 
l8111h:
	ld a,(hl)			;8111	7e 	~ 
	cp 009h		;8112	fe 09 	. . 
	jr z,l811eh		;8114	28 08 	( . 
	cp 01ah		;8116	fe 1a 	. . 
	ret z			;8118	c8 	. 
	cp 00dh		;8119	fe 0d 	. . 
	ret z			;811b	c8 	. 
	or a			;811c	b7 	. 
	ret z			;811d	c8 	. 
l811eh:
	inc hl			;811e	23 	# 
	djnz l8111h		;811f	10 f0 	. . 
	push hl			;8121	e5 	. 
	ld hl,0000ah		;8122	21 0a 00 	! . . 
	add hl,de			;8125	19 	. 
	ld d,h			;8126	54 	T 
	ld e,l			;8127	5d 	] 
	pop hl			;8128	e1 	. 
	jr l80feh		;8129	18 d3 	. . 
recompute_window_top:
	ld hl,00000h		;812b	21 00 00 	! . . 
l812eh:
	ld (window_left_column),hl		;812e	22 e8 8c 	" . . 
	call scan_visible_line_start		;8131	cd f8 80 	. . . 
	ld hl,(edit_ptr)		;8134	2a de 8c 	* . . 
	ld de,(visible_line_ptr)		;8137	ed 5b f0 8c 	. [ . . 
	xor a			;813b	af 	. 
	sbc hl,de		;813c	ed 52 	. R 
	ld a,l			;813e	7d 	} 
	ld (line_visible_len),a		;813f	32 fb 8c 	2 . . 
	ld de,00028h		;8142	11 28 00 	. ( . 
	sbc hl,de		;8145	ed 52 	. R 
	ret c			;8147	d8 	. 
	ld de,0000ah		;8148	11 0a 00 	. . . 
	ld hl,(visible_line_column)		;814b	2a ea 8c 	* . . 
	add hl,de			;814e	19 	. 
	jr l812eh		;814f	18 dd 	. . 
clamp_column_after_vertical_move:
	ld a,(cursor_column)		;8151	3a f6 8c 	: . . 
	ld e,a			;8154	5f 	_ 
	ld d,000h		;8155	16 00 	. . 
	ld hl,(screen_cursor_ptr)		;8157	2a e2 8c 	* . . 
	xor a			;815a	af 	. 
	sbc hl,de		;815b	ed 52 	. R 
	push hl			;815d	e5 	. 
	call measure_column_on_line		;815e	cd 6b 81 	. k . 
	pop hl			;8161	e1 	. 
	add hl,de			;8162	19 	. 
	ld (screen_cursor_ptr),hl		;8163	22 e2 8c 	" . . 
	ld a,e			;8166	7b 	{ 
	ld (cursor_column),a		;8167	32 f6 8c 	2 . . 
	ret			;816a	c9 	. 
measure_column_on_line:
	ld hl,(visible_line_ptr)		;816b	2a f0 8c 	* . . 
	ld a,(cursor_column)		;816e	3a f6 8c 	: . . 
	or a			;8171	b7 	. 
	ld c,000h		;8172	0e 00 	. . 
	jr z,l8187h		;8174	28 11 	( . 
	ld b,a			;8176	47 	G 
l8177h:
	ld a,(hl)			;8177	7e 	~ 
	cp 00dh		;8178	fe 0d 	. . 
	jr z,l8187h		;817a	28 0b 	( . 
	or a			;817c	b7 	. 
	jr z,l8187h		;817d	28 08 	( . 
	cp 01ah		;817f	fe 1a 	. . 
	jr z,l8187h		;8181	28 04 	( . 
	inc hl			;8183	23 	# 
	inc c			;8184	0c 	. 
	djnz l8177h		;8185	10 f0 	. . 
l8187h:
	ld e,c			;8187	59 	Y 
	ret			;8188	c9 	. 
cursor_down_or_scroll:
	ld a,(cursor_row)		;8189	3a f7 8c 	: . . 
	inc a			;818c	3c 	< 
	cp 016h		;818d	fe 16 	. . 
	jr nc,l819fh		;818f	30 0e 	0 . 
	ld (cursor_row),a		;8191	32 f7 8c 	2 . . 
	ld hl,(screen_cursor_ptr)		;8194	2a e2 8c 	* . . 
	ld de,00028h		;8197	11 28 00 	. ( . 
	add hl,de			;819a	19 	. 
	ld (screen_cursor_ptr),hl		;819b	22 e2 8c 	" . . 
	ret			;819e	c9 	. 
l819fh:
	ld hl,(window_top_ptr)		;819f	2a e0 8c 	* . . 
	call l80d7h		;81a2	cd d7 80 	. . . 
	ld (window_top_ptr),hl		;81a5	22 e0 8c 	" . . 
	ret			;81a8	c9 	. 
cursor_up_or_scroll:
	ld a,(cursor_row)		;81a9	3a f7 8c 	: . . 
	sub 001h		;81ac	d6 01 	. . 
	jr c,l81bfh		;81ae	38 0f 	8 . 
	ld (cursor_row),a		;81b0	32 f7 8c 	2 . . 
	ld hl,(screen_cursor_ptr)		;81b3	2a e2 8c 	* . . 
	ld de,00028h		;81b6	11 28 00 	. ( . 
	sbc hl,de		;81b9	ed 52 	. R 
	ld (screen_cursor_ptr),hl		;81bb	22 e2 8c 	" . . 
	ret			;81be	c9 	. 
l81bfh:
	ld hl,(window_top_ptr)		;81bf	2a e0 8c 	* . . 
	call find_previous_line		;81c2	cd e5 80 	. . . 
	ld (window_top_ptr),hl		;81c5	22 e0 8c 	" . . 
	ret			;81c8	c9 	. 
ensure_space_for_insert:
	ld a,(insert_mode)		;81c9	3a f9 8c 	: . . 
	or a			;81cc	b7 	. 
	jr nz,l81dbh		;81cd	20 0c 	  . 
	ld hl,(edit_ptr)		;81cf	2a de 8c 	* . . 
	ld a,(hl)			;81d2	7e 	~ 
	cp 00dh		;81d3	fe 0d 	. . 
	jr z,l81dbh		;81d5	28 04 	( . 
	cp 01ah		;81d7	fe 1a 	. . 
	scf			;81d9	37 	7 
	ret nz			;81da	c0 	. 
l81dbh:
	call has_free_text_space		;81db	cd fc 81 	. . . 
	ret nc			;81de	d0 	. 
	ld de,(edit_ptr)		;81df	ed 5b de 8c 	. [ . . 
make_gap_for_insert:
	xor a			;81e3	af 	. 
	sbc hl,de		;81e4	ed 52 	. R 
	ld b,h			;81e6	44 	D 
	ld c,l			;81e7	4d 	M 
	ld hl,(text_end_ptr)		;81e8	2a e6 8c 	* . . 
	inc hl			;81eb	23 	# 
	inc hl			;81ec	23 	# 
	ld d,h			;81ed	54 	T 
	ld e,l			;81ee	5d 	] 
	inc bc			;81ef	03 	. 
	inc bc			;81f0	03 	. 
l81f1h:
	dec hl			;81f1	2b 	+ 
	ld a,(hl)			;81f2	7e 	~ 
	ld (de),a			;81f3	12 	. 
	dec de			;81f4	1b 	. 
	dec bc			;81f5	0b 	. 
	ld a,b			;81f6	78 	x 
	or c			;81f7	b1 	. 
	jr nz,l81f1h		;81f8	20 f7 	  . 
	scf			;81fa	37 	7 
	ret			;81fb	c9 	. 
has_free_text_space:
	ld hl,(text_end_ptr)		;81fc	2a e6 8c 	* . . 
	push hl			;81ff	e5 	. 
	ld de,text_buffer_start		;8200	11 7f 8d 	.  . 
	or a			;8203	b7 	. 
	sbc hl,de		;8204	ed 52 	. R 
	ld de,02008h		;8206	11 08 20 	. .   
	or a			;8209	b7 	. 
	sbc hl,de		;820a	ed 52 	. R 
	pop hl			;820c	e1 	. 
	jr nc,l8217h		;820d	30 08 	0 . 
	inc hl			;820f	23 	# 
	ld (text_end_ptr),hl		;8210	22 e6 8c 	" . . 
	ld (hl),01ah		;8213	36 1a 	6 . 
	scf			;8215	37 	7 
	ret			;8216	c9 	. 
l8217h:
	ld hl,003aeh		;8217	21 ae 03 	! . . 
	call goto_xy_from_hl		;821a	cd d4 86 	. . . 
	ld hl,l822dh		;821d	21 2d 82 	! - . 
	ld b,014h		;8220	06 14 	. . 
	call draw_b_chars_from_hl		;8222	cd 58 86 	. X . 
	ld de,005dch		;8225	11 dc 05 	. . . 
	call 08caeh		;8228	cd ae 8c 	. . . 
	or a			;822b	b7 	. 
	ret			;822c	c9 	. 
l822dh:
	ld c,(hl)			;822d	4e 	N 
	ld l,a			;822e	6f 	o 
	ld (hl),h			;822f	74 	t 
	jr nz,$+71		;8230	20 45 	  E 
	ld l,(hl)			;8232	6e 	n 
	ld l,a			;8233	6f 	o 
	ld (hl),l			;8234	75 	u 
	ld h,a			;8235	67 	g 
	ld l,b			;8236	68 	h 
	jr nz,$+79		;8237	20 4d 	  M 
	ld h,l			;8239	65 	e 
	ld l,l			;823a	6d 	m 
	ld l,a			;823b	6f 	o 
	ld (hl),d			;823c	72 	r 
	ld a,c			;823d	79 	y 
	ld hl,03a0dh		;823e	21 0d 3a 	! . : 
	or 08ch		;8241	f6 8c 	. . 
	ld b,a			;8243	47 	G 
	ld a,028h		;8244	3e 28 	> ( 
	sub b			;8246	90 	. 
	ret z			;8247	c8 	. 
	ld b,a			;8248	47 	G 
	ld hl,(screen_cursor_ptr)		;8249	2a e2 8c 	* . . 
	call goto_xy_from_hl		;824c	cd d4 86 	. . . 
	ld hl,(edit_ptr)		;824f	2a de 8c 	* . . 
l8252h:
	inc hl			;8252	23 	# 
	ld a,(hl)			;8253	7e 	~ 
	cp 00dh		;8254	fe 0d 	. . 
	ret z			;8256	c8 	. 
	cp 00ah		;8257	fe 0a 	. . 
	ret z			;8259	c8 	. 
	cp 01ah		;825a	fe 1a 	. . 
	ret z			;825c	c8 	. 
	out (VDP_DATA_PORT),a		;825d	d3 98 	. . 
	djnz l8252h		;825f	10 f1 	. . 
	ret			;8261	c9 	. 
advance_cursor_after_insert:
	ld a,(cursor_column)		;8262	3a f6 8c 	: . . 
	add a,001h		;8265	c6 01 	. . 
	cp 028h		;8267	fe 28 	. ( 
	jr c,l8284h		;8269	38 19 	8 . 
	sub 00ah		;826b	d6 0a 	. . 
	ld (cursor_column),a		;826d	32 f6 8c 	2 . . 
	ld de,00009h		;8270	11 09 00 	. . . 
	ld hl,(screen_cursor_ptr)		;8273	2a e2 8c 	* . . 
	sbc hl,de		;8276	ed 52 	. R 
	ld (screen_cursor_ptr),hl		;8278	22 e2 8c 	" . . 
	ld hl,(window_left_column)		;827b	2a e8 8c 	* . . 
	inc de			;827e	13 	. 
	add hl,de			;827f	19 	. 
	ld (window_left_column),hl		;8280	22 e8 8c 	" . . 
	ret			;8283	c9 	. 
l8284h:
	ld (cursor_column),a		;8284	32 f6 8c 	2 . . 
	ld hl,(screen_cursor_ptr)		;8287	2a e2 8c 	* . . 
	inc hl			;828a	23 	# 
	ld (screen_cursor_ptr),hl		;828b	22 e2 8c 	" . . 
	xor a			;828e	af 	. 
	ret			;828f	c9 	. 
l8290h:
	ld a,(insert_mode)		;8290	3a f9 8c 	: . . 
	or a			;8293	b7 	. 
	jr nz,l829eh		;8294	20 08 	  . 
	ld hl,(edit_ptr)		;8296	2a de 8c 	* . . 
	ld a,(hl)			;8299	7e 	~ 
	cp 01ah		;829a	fe 1a 	. . 
	jr nz,l82b2h		;829c	20 14 	  . 
l829eh:
	call l81dbh		;829e	cd db 81 	. . . 
	jp nc,editor_start		;82a1	d2 00 80 	. . . 
	call append_key_to_buffer		;82a4	cd ac 80 	. . . 
	call l81dbh		;82a7	cd db 81 	. . . 
	call append_key_to_buffer		;82aa	cd ac 80 	. . . 
	dec hl			;82ad	2b 	+ 
	ld (hl),00ah		;82ae	36 0a 	6 . 
	jr l82beh		;82b0	18 0c 	. . 
l82b2h:
	call l80d7h		;82b2	cd d7 80 	. . . 
	ld (edit_ptr),hl		;82b5	22 de 8c 	" . . 
	dec hl			;82b8	2b 	+ 
	ld a,(hl)			;82b9	7e 	~ 
	cp 00ah		;82ba	fe 0a 	. . 
	jr nz,l829eh		;82bc	20 e0 	  . 
l82beh:
	call refresh_after_new_line		;82be	cd c6 82 	. . . 
	call cursor_down_or_scroll		;82c1	cd 89 81 	. . . 
	jr l82deh		;82c4	18 18 	. . 
refresh_after_new_line:
	ld de,00000h		;82c6	11 00 00 	. . . 
	ld (window_left_column),de		;82c9	ed 53 e8 8c 	. S . . 
	ld a,(cursor_column)		;82cd	3a f6 8c 	: . . 
	ld e,a			;82d0	5f 	_ 
	xor a			;82d1	af 	. 
	ld hl,(screen_cursor_ptr)		;82d2	2a e2 8c 	* . . 
	sbc hl,de		;82d5	ed 52 	. R 
	ld (screen_cursor_ptr),hl		;82d7	22 e2 8c 	" . . 
	ld (cursor_column),a		;82da	32 f6 8c 	2 . . 
	ret			;82dd	c9 	. 
l82deh:
	jp editor_start		;82de	c3 00 80 	. . . 
l82e1h:
	ld a,(insert_mode)		;82e1	3a f9 8c 	: . . 
	ld e,001h		;82e4	1e 01 	. . 
	or a			;82e6	b7 	. 
	jr z,l82eah		;82e7	28 01 	( . 
	dec e			;82e9	1d 	. 
l82eah:
	ld a,e			;82ea	7b 	{ 
	ld (insert_mode),a		;82eb	32 f9 8c 	2 . . 
	call redraw_screen		;82ee	cd ff 85 	. . . 
	jp editor_loop		;82f1	c3 06 80 	. . . 
l82f4h:
	ld hl,(edit_ptr)		;82f4	2a de 8c 	* . . 
	call compare_de_with_text_limit		;82f7	cd d0 80 	. . . 
	jp z,editor_loop		;82fa	ca 06 80 	. . . 
	ld a,(saved_char_under_cursor)		;82fd	3a 02 8d 	: . . 
	bit 0,a		;8300	cb 47 	. G 
	jr z,l8318h		;8302	28 14 	( . 
	bit 1,a		;8304	cb 4f 	. O 
	jr z,l8341h		;8306	28 39 	( 9 
	call delete_previous_char		;8308	cd 0e 83 	. . . 
	jp editor_start		;830b	c3 00 80 	. . . 
delete_previous_char:
	call move_cursor_left		;830e	cd 27 84 	. ' . 
	ld hl,(edit_ptr)		;8311	2a de 8c 	* . . 
	call is_line_boundary_or_eof		;8314	cd aa 85 	. . . 
	ret			;8317	c9 	. 
l8318h:
	call delete_previous_char_loop		;8318	cd 1e 83 	. . . 
	jp editor_start		;831b	c3 00 80 	. . . 
delete_previous_char_loop:
	dec hl			;831e	2b 	+ 
	ld a,(hl)			;831f	7e 	~ 
	push af			;8320	f5 	. 
	call move_cursor_left		;8321	cd 27 84 	. ' . 
	ld hl,(edit_ptr)		;8324	2a de 8c 	* . . 
	push hl			;8327	e5 	. 
	call is_line_boundary_or_eof		;8328	cd aa 85 	. . . 
	pop hl			;832b	e1 	. 
	pop de			;832c	d1 	. 
	ld a,d			;832d	7a 	z 
	cp 00ah		;832e	fe 0a 	. . 
	ret z			;8330	c8 	. 
	dec hl			;8331	2b 	+ 
	ld a,(hl)			;8332	7e 	~ 
	cp 00ah		;8333	fe 0a 	. . 
	ret z			;8335	c8 	. 
	cp 020h		;8336	fe 20 	.   
	jr nz,delete_previous_char_loop		;8338	20 e4 	  . 
	dec hl			;833a	2b 	+ 
	ld a,(hl)			;833b	7e 	~ 
	cp 020h		;833c	fe 20 	.   
	jr z,delete_previous_char_loop		;833e	28 de 	( . 
	ret			;8340	c9 	. 
l8341h:
	push hl			;8341	e5 	. 
	call find_line_start_backward		;8342	cd f0 80 	. . . 
	ld (edit_ptr),hl		;8345	22 de 8c 	" . . 
	ex (sp),hl			;8348	e3 	. 
	push hl			;8349	e5 	. 
	call refresh_after_new_line		;834a	cd c6 82 	. . . 
	pop hl			;834d	e1 	. 
	jp l85e7h		;834e	c3 e7 85 	. . . 
delete_range_at_cursor:
	ld d,h			;8351	54 	T 
	ld e,l			;8352	5d 	] 
	inc hl			;8353	23 	# 
	push hl			;8354	e5 	. 
	ld b,h			;8355	44 	D 
	ld c,l			;8356	4d 	M 
	ld hl,(text_end_ptr)		;8357	2a e6 8c 	* . . 
	dec hl			;835a	2b 	+ 
	ld (text_end_ptr),hl		;835b	22 e6 8c 	" . . 
	inc hl			;835e	23 	# 
	xor a			;835f	af 	. 
	sbc hl,bc		;8360	ed 42 	. B 
	ld b,h			;8362	44 	D 
	ld c,l			;8363	4d 	M 
	inc bc			;8364	03 	. 
	pop hl			;8365	e1 	. 
	ldir		;8366	ed b0 	. . 
	ret			;8368	c9 	. 
l8369h:
	ld hl,(edit_ptr)		;8369	2a de 8c 	* . . 
	call find_previous_line		;836c	cd e5 80 	. . . 
	call compare_de_with_text_limit		;836f	cd d0 80 	. . . 
	jp c,editor_loop		;8372	da 06 80 	. . . 
	ld a,(saved_char_under_cursor)		;8375	3a 02 8d 	: . . 
	bit 0,a		;8378	cb 47 	. G 
	jp z,l839bh		;837a	ca 9b 83 	. . . 
	bit 1,a		;837d	cb 4f 	. O 
	jp z,l83b6h		;837f	ca b6 83 	. . . 
	call scan_visible_line_start		;8382	cd f8 80 	. . . 
	ld hl,(visible_line_column)		;8385	2a ea 8c 	* . . 
	ld (window_left_column),hl		;8388	22 e8 8c 	" . . 
	call clamp_column_after_vertical_move		;838b	cd 51 81 	. Q . 
	ld hl,(visible_line_ptr)		;838e	2a f0 8c 	* . . 
	add hl,de			;8391	19 	. 
	ld (edit_ptr),hl		;8392	22 de 8c 	" . . 
	call cursor_up_or_scroll		;8395	cd a9 81 	. . . 
	jp editor_start		;8398	c3 00 80 	. . . 
l839bh:
	ld hl,(window_top_ptr)		;839b	2a e0 8c 	* . . 
	call compare_de_with_text_limit		;839e	cd d0 80 	. . . 
	jp z,editor_loop		;83a1	ca 06 80 	. . . 
	call find_previous_line		;83a4	cd e5 80 	. . . 
	ld (window_top_ptr),hl		;83a7	22 e0 8c 	" . . 
	ld hl,(edit_ptr)		;83aa	2a de 8c 	* . . 
	call find_previous_line		;83ad	cd e5 80 	. . . 
l83b0h:
	call copy_until_linebreak		;83b0	cd 4e 8a 	. N . 
	jp editor_start		;83b3	c3 00 80 	. . . 
l83b6h:
	ld b,012h		;83b6	06 12 	. . 
l83b8h:
	ld hl,(window_top_ptr)		;83b8	2a e0 8c 	* . . 
	call find_previous_line		;83bb	cd e5 80 	. . . 
	call compare_de_with_text_limit		;83be	cd d0 80 	. . . 
	jr c,l83d1h		;83c1	38 0e 	8 . 
	ld (window_top_ptr),hl		;83c3	22 e0 8c 	" . . 
	ld hl,(edit_ptr)		;83c6	2a de 8c 	* . . 
	call find_previous_line		;83c9	cd e5 80 	. . . 
	ld (edit_ptr),hl		;83cc	22 de 8c 	" . . 
	djnz l83b8h		;83cf	10 e7 	. . 
l83d1h:
	ld hl,(edit_ptr)		;83d1	2a de 8c 	* . . 
	ld (line_start_ptr),hl		;83d4	22 ee 8c 	" . . 
	jr l83b0h		;83d7	18 d7 	. . 
l83d9h:
	ld hl,(edit_ptr)		;83d9	2a de 8c 	* . . 
	call l80d7h		;83dc	cd d7 80 	. . . 
	ld a,(hl)			;83df	7e 	~ 
	cp 01ah		;83e0	fe 1a 	. . 
	jp z,editor_loop		;83e2	ca 06 80 	. . . 
	ld a,(saved_char_under_cursor)		;83e5	3a 02 8d 	: . . 
	bit 0,a		;83e8	cb 47 	. G 
	jp z,l8493h		;83ea	ca 93 84 	. . . 
	bit 1,a		;83ed	cb 4f 	. O 
	jp z,l84a8h		;83ef	ca a8 84 	. . . 
	call scan_visible_line_start		;83f2	cd f8 80 	. . . 
	ld hl,(visible_line_column)		;83f5	2a ea 8c 	* . . 
	ld (window_left_column),hl		;83f8	22 e8 8c 	" . . 
	call clamp_column_after_vertical_move		;83fb	cd 51 81 	. Q . 
	ld hl,(visible_line_ptr)		;83fe	2a f0 8c 	* . . 
	add hl,de			;8401	19 	. 
	ld (edit_ptr),hl		;8402	22 de 8c 	" . . 
	call cursor_down_or_scroll		;8405	cd 89 81 	. . . 
	jp editor_start		;8408	c3 00 80 	. . . 
l840bh:
	ld hl,(edit_ptr)		;840b	2a de 8c 	* . . 
	call compare_de_with_text_limit		;840e	cd d0 80 	. . . 
	jp z,editor_loop		;8411	ca 06 80 	. . . 
	ld a,(saved_char_under_cursor)		;8414	3a 02 8d 	: . . 
	bit 0,a		;8417	cb 47 	. G 
	jp z,l84cbh		;8419	ca cb 84 	. . . 
	bit 1,a		;841c	cb 4f 	. O 
	jp z,l84d1h		;841e	ca d1 84 	. . . 
	call move_cursor_left		;8421	cd 27 84 	. ' . 
	jp editor_start		;8424	c3 00 80 	. . . 
move_cursor_left:
	ld a,(cursor_column)		;8427	3a f6 8c 	: . . 
	sub 001h		;842a	d6 01 	. . 
	jr nc,l8432h		;842c	30 04 	0 . 
	call move_left_across_line		;842e	cd 36 84 	. 6 . 
	ret			;8431	c9 	. 
l8432h:
	call move_cursor_right		;8432	cd 85 84 	. . . 
	ret			;8435	c9 	. 
move_left_across_line:
	ld hl,(window_left_column)		;8436	2a e8 8c 	* . . 
	ld a,h			;8439	7c 	| 
	or l			;843a	b5 	. 
	jr z,l8457h		;843b	28 1a 	( . 
	ld de,0000ah		;843d	11 0a 00 	. . . 
	xor a			;8440	af 	. 
	sbc hl,de		;8441	ed 52 	. R 
	ld (window_left_column),hl		;8443	22 e8 8c 	" . . 
	call move_edit_ptr_back_one_char		;8446	cd b8 80 	. . . 
	ld hl,(screen_cursor_ptr)		;8449	2a e2 8c 	* . . 
	add hl,de			;844c	19 	. 
	dec hl			;844d	2b 	+ 
	ld (screen_cursor_ptr),hl		;844e	22 e2 8c 	" . . 
	ld a,009h		;8451	3e 09 	> . 
	ld (cursor_column),a		;8453	32 f6 8c 	2 . . 
	ret			;8456	c9 	. 
l8457h:
	ld hl,(edit_ptr)		;8457	2a de 8c 	* . . 
	call find_line_start_backward		;845a	cd f0 80 	. . . 
	dec hl			;845d	2b 	+ 
	dec hl			;845e	2b 	+ 
	ld (edit_ptr),hl		;845f	22 de 8c 	" . . 
	call find_line_start_backward		;8462	cd f0 80 	. . . 
	ld (line_start_ptr),hl		;8465	22 ee 8c 	" . . 
	call recompute_window_top		;8468	cd 2b 81 	. + . 
	ld hl,(edit_ptr)		;846b	2a de 8c 	* . . 
	ld de,(visible_line_ptr)		;846e	ed 5b f0 8c 	. [ . . 
	xor a			;8472	af 	. 
	sbc hl,de		;8473	ed 52 	. R 
	ld de,(screen_cursor_ptr)		;8475	ed 5b e2 8c 	. [ . . 
	ld a,l			;8479	7d 	} 
	add hl,de			;847a	19 	. 
	ld (screen_cursor_ptr),hl		;847b	22 e2 8c 	" . . 
	ld (cursor_column),a		;847e	32 f6 8c 	2 . . 
	call cursor_up_or_scroll		;8481	cd a9 81 	. . . 
	ret			;8484	c9 	. 
move_cursor_right:
	ld (cursor_column),a		;8485	32 f6 8c 	2 . . 
	ld hl,(screen_cursor_ptr)		;8488	2a e2 8c 	* . . 
	dec hl			;848b	2b 	+ 
	ld (screen_cursor_ptr),hl		;848c	22 e2 8c 	" . . 
	call move_edit_ptr_back_one_char		;848f	cd b8 80 	. . . 
	ret			;8492	c9 	. 
l8493h:
	ld hl,(window_top_ptr)		;8493	2a e0 8c 	* . . 
	call l80d7h		;8496	cd d7 80 	. . . 
	ld (window_top_ptr),hl		;8499	22 e0 8c 	" . . 
	ld hl,(edit_ptr)		;849c	2a de 8c 	* . . 
	call l80d7h		;849f	cd d7 80 	. . . 
l84a2h:
	call copy_until_linebreak		;84a2	cd 4e 8a 	. N . 
	jp editor_start		;84a5	c3 00 80 	. . . 
l84a8h:
	ld b,012h		;84a8	06 12 	. . 
l84aah:
	ld hl,(edit_ptr)		;84aa	2a de 8c 	* . . 
	call l80d7h		;84ad	cd d7 80 	. . . 
	ld a,(hl)			;84b0	7e 	~ 
	cp 01ah		;84b1	fe 1a 	. . 
	jr z,l84c3h		;84b3	28 0e 	( . 
	ld (edit_ptr),hl		;84b5	22 de 8c 	" . . 
	ld hl,(window_top_ptr)		;84b8	2a e0 8c 	* . . 
	call l80d7h		;84bb	cd d7 80 	. . . 
	ld (window_top_ptr),hl		;84be	22 e0 8c 	" . . 
	djnz l84aah		;84c1	10 e7 	. . 
l84c3h:
	ld hl,(edit_ptr)		;84c3	2a de 8c 	* . . 
	ld (line_start_ptr),hl		;84c6	22 ee 8c 	" . . 
	jr l84a2h		;84c9	18 d7 	. . 
l84cbh:
	call advance_one_char		;84cb	cd e0 84 	. . . 
	jp editor_start		;84ce	c3 00 80 	. . . 
l84d1h:
	ld hl,(edit_ptr)		;84d1	2a de 8c 	* . . 
	dec hl			;84d4	2b 	+ 
	ld a,(hl)			;84d5	7e 	~ 
	cp 00ah		;84d6	fe 0a 	. . 
	jp z,editor_start		;84d8	ca 00 80 	. . . 
	call move_cursor_left		;84db	cd 27 84 	. ' . 
	jr l84d1h		;84de	18 f1 	. . 
advance_one_char:
	ld hl,(edit_ptr)		;84e0	2a de 8c 	* . . 
	dec hl			;84e3	2b 	+ 
	ld a,(hl)			;84e4	7e 	~ 
	cp 00ah		;84e5	fe 0a 	. . 
	jr z,l84edh		;84e7	28 04 	( . 
	cp 020h		;84e9	fe 20 	.   
	jr nz,l84f0h		;84eb	20 03 	  . 
l84edh:
	call skip_to_line_end_or_eof		;84ed	cd 04 85 	. . . 
l84f0h:
	ld hl,(edit_ptr)		;84f0	2a de 8c 	* . . 
	call compare_de_with_text_limit		;84f3	cd d0 80 	. . . 
	ret z			;84f6	c8 	. 
	dec hl			;84f7	2b 	+ 
	ld a,(hl)			;84f8	7e 	~ 
	cp 020h		;84f9	fe 20 	.   
	ret z			;84fb	c8 	. 
	cp 00ah		;84fc	fe 0a 	. . 
	ret z			;84fe	c8 	. 
	call move_cursor_left		;84ff	cd 27 84 	. ' . 
	jr l84f0h		;8502	18 ec 	. . 
skip_to_line_end_or_eof:
	call move_cursor_left		;8504	cd 27 84 	. ' . 
	ld hl,(edit_ptr)		;8507	2a de 8c 	* . . 
	call compare_de_with_text_limit		;850a	cd d0 80 	. . . 
	ret z			;850d	c8 	. 
	ld a,(hl)			;850e	7e 	~ 
	cp 020h		;850f	fe 20 	.   
	jr z,skip_to_line_end_or_eof		;8511	28 f1 	( . 
	ret			;8513	c9 	. 
l8514h:
	ld hl,(edit_ptr)		;8514	2a de 8c 	* . . 
	call compare_de_with_text_end		;8517	cd c8 80 	. . . 
	jp nc,editor_loop		;851a	d2 06 80 	. . . 
	ld a,(saved_char_under_cursor)		;851d	3a 02 8d 	: . . 
	bit 0,a		;8520	cb 47 	. G 
	jr z,l8530h		;8522	28 0c 	( . 
	bit 1,a		;8524	cb 4f 	. O 
	jr z,l8536h		;8526	28 0e 	( . 
	xor a			;8528	af 	. 
	ld (insert_mode),a		;8529	32 f9 8c 	2 . . 
	ld a,(hl)			;852c	7e 	~ 
	jp dispatch_key		;852d	c3 12 80 	. . . 
l8530h:
	call erase_current_line_region		;8530	cd 4d 85 	. M . 
	jp editor_start		;8533	c3 00 80 	. . . 
l8536h:
	ld hl,(edit_ptr)		;8536	2a de 8c 	* . . 
	ld a,(hl)			;8539	7e 	~ 
	cp 00dh		;853a	fe 0d 	. . 
	jp z,editor_start		;853c	ca 00 80 	. . . 
	cp 01ah		;853f	fe 1a 	. . 
	jp z,editor_start		;8541	ca 00 80 	. . . 
	inc hl			;8544	23 	# 
	ld (edit_ptr),hl		;8545	22 de 8c 	" . . 
	call advance_cursor_after_insert		;8548	cd 62 82 	. b . 
	jr l8536h		;854b	18 e9 	. . 
erase_current_line_region:
	ld hl,(edit_ptr)		;854d	2a de 8c 	* . . 
	inc hl			;8550	23 	# 
	ld a,(hl)			;8551	7e 	~ 
	dec hl			;8552	2b 	+ 
	cp 020h		;8553	fe 20 	.   
	jr z,l8580h		;8555	28 29 	( ) 
l8557h:
	ld hl,(edit_ptr)		;8557	2a de 8c 	* . . 
	call compare_de_with_text_end		;855a	cd c8 80 	. . . 
	ret nc			;855d	d0 	. 
	ld a,(hl)			;855e	7e 	~ 
	cp 01ah		;855f	fe 1a 	. . 
	ret z			;8561	c8 	. 
	cp 020h		;8562	fe 20 	.   
	jr z,l8580h		;8564	28 1a 	( . 
	cp 00dh		;8566	fe 0d 	. . 
	jr nz,l8577h		;8568	20 0d 	  . 
	inc hl			;856a	23 	# 
	inc hl			;856b	23 	# 
	ld (edit_ptr),hl		;856c	22 de 8c 	" . . 
	call refresh_after_new_line		;856f	cd c6 82 	. . . 
	call cursor_down_or_scroll		;8572	cd 89 81 	. . . 
	jr l8587h		;8575	18 10 	. . 
l8577h:
	inc hl			;8577	23 	# 
	ld (edit_ptr),hl		;8578	22 de 8c 	" . . 
	call advance_cursor_after_insert		;857b	cd 62 82 	. b . 
	jr l8557h		;857e	18 d7 	. . 
l8580h:
	inc hl			;8580	23 	# 
	ld (edit_ptr),hl		;8581	22 de 8c 	" . . 
	call advance_cursor_after_insert		;8584	cd 62 82 	. b . 
l8587h:
	ld hl,(edit_ptr)		;8587	2a de 8c 	* . . 
	ld a,(hl)			;858a	7e 	~ 
	cp 020h		;858b	fe 20 	.   
	ret nz			;858d	c0 	. 
	jr l8580h		;858e	18 f0 	. . 
l8590h:
	ld hl,(edit_ptr)		;8590	2a de 8c 	* . . 
	call compare_de_with_text_end		;8593	cd c8 80 	. . . 
	jp nc,editor_loop		;8596	d2 06 80 	. . . 
	ld a,(saved_char_under_cursor)		;8599	3a 02 8d 	: . . 
	bit 0,a		;859c	cb 47 	. G 
	jr z,l85b6h		;859e	28 16 	( . 
	bit 1,a		;85a0	cb 4f 	. O 
	jr z,l85dch		;85a2	28 38 	( 8 
	call is_line_boundary_or_eof		;85a4	cd aa 85 	. . . 
	jp editor_start		;85a7	c3 00 80 	. . . 
is_line_boundary_or_eof:
	ld a,(hl)			;85aa	7e 	~ 
	push hl			;85ab	e5 	. 
	cp 00dh		;85ac	fe 0d 	. . 
	call z,delete_range_at_cursor		;85ae	cc 51 83 	. Q . 
	pop hl			;85b1	e1 	. 
	call delete_range_at_cursor		;85b2	cd 51 83 	. Q . 
	ret			;85b5	c9 	. 
l85b6h:
	call draw_line_from_hl		;85b6	cd bc 85 	. . . 
	jp editor_start		;85b9	c3 00 80 	. . . 
draw_line_from_hl:
	ld a,(hl)			;85bc	7e 	~ 
	push af			;85bd	f5 	. 
	push hl			;85be	e5 	. 
	call is_line_boundary_or_eof		;85bf	cd aa 85 	. . . 
	pop hl			;85c2	e1 	. 
	pop af			;85c3	f1 	. 
	cp 00dh		;85c4	fe 0d 	. . 
	ret z			;85c6	c8 	. 
	ld a,(hl)			;85c7	7e 	~ 
	cp 020h		;85c8	fe 20 	.   
	jr z,l85d4h		;85ca	28 08 	( . 
	cp 00dh		;85cc	fe 0d 	. . 
	ret z			;85ce	c8 	. 
	cp 01ah		;85cf	fe 1a 	. . 
	ret z			;85d1	c8 	. 
	jr draw_line_from_hl		;85d2	18 e8 	. . 
l85d4h:
	inc hl			;85d4	23 	# 
	ld a,(hl)			;85d5	7e 	~ 
	dec hl			;85d6	2b 	+ 
	cp 020h		;85d7	fe 20 	.   
	jr z,draw_line_from_hl		;85d9	28 e1 	( . 
	ret			;85db	c9 	. 
l85dch:
	push hl			;85dc	e5 	. 
	call l80d7h		;85dd	cd d7 80 	. . . 
	ld a,(hl)			;85e0	7e 	~ 
	cp 01ah		;85e1	fe 1a 	. . 
	jr z,l85e7h		;85e3	28 02 	( . 
	dec hl			;85e5	2b 	+ 
	dec hl			;85e6	2b 	+ 
l85e7h:
	push hl			;85e7	e5 	. 
	ld de,(text_end_ptr)		;85e8	ed 5b e6 8c 	. [ . . 
	ex de,hl			;85ec	eb 	. 
	xor a			;85ed	af 	. 
	sbc hl,de		;85ee	ed 52 	. R 
	ld b,h			;85f0	44 	D 
	ld c,l			;85f1	4d 	M 
	pop hl			;85f2	e1 	. 
	pop de			;85f3	d1 	. 
	inc bc			;85f4	03 	. 
	ldir		;85f5	ed b0 	. . 
	dec de			;85f7	1b 	. 
	ld (text_end_ptr),de		;85f8	ed 53 e6 8c 	. S . . 
	jp editor_start		;85fc	c3 00 80 	. . . 
redraw_screen:
	ld hl,003bch		;85ff	21 bc 03 	! . . 
	call goto_xy_from_hl		;8602	cd d4 86 	. . . 
	ld a,(insert_mode)		;8605	3a f9 8c 	: . . 
	ld hl,l861ch		;8608	21 1c 86 	! . . 
	or a			;860b	b7 	. 
	jr z,l8611h		;860c	28 03 	( . 
	ld hl,l8617h		;860e	21 17 86 	! . . 
l8611h:
	ld b,004h		;8611	06 04 	. . 
	call draw_b_chars_from_hl		;8613	cd 58 86 	. X . 
	ret			;8616	c9 	. 
l8617h:
	ld c,c			;8617	49 	I 
	ld l,(hl)			;8618	6e 	n 
	ld (hl),e			;8619	73 	s 
	jr nz,l8629h		;861a	20 0d 	  . 
l861ch:
	ld c,a			;861c	4f 	O 
	halt			;861d	76 	v 
	ld h,l			;861e	65 	e 
	ld (hl),d			;861f	72 	r 
	dec c			;8620	0d 	. 
l8621h:
	ld a,(hl)			;8621	7e 	~ 
	cp 01ah		;8622	fe 1a 	. . 
	ret z			;8624	c8 	. 
	inc hl			;8625	23 	# 
	inc hl			;8626	23 	# 
	cp 00dh		;8627	fe 0d 	. . 
l8629h:
	ret z			;8629	c8 	. 
	dec hl			;862a	2b 	+ 
	jr l8621h		;862b	18 f4 	. . 
	ret			;862d	c9 	. 
init_editor_state:
	ld hl,00000h		;862e	21 00 00 	! . . 
	call goto_xy_from_hl		;8631	cd d4 86 	. . . 
	ld hl,(window_top_ptr)		;8634	2a e0 8c 	* . . 
	ld c,016h		;8637	0e 16 	. . 
l8639h:
	ld b,028h		;8639	06 28 	. ( 
	push bc			;863b	c5 	. 
	call draw_string_until_cr		;863c	cd 65 86 	. e . 
	pop bc			;863f	c1 	. 
	call draw_b_chars_from_hl		;8640	cd 58 86 	. X . 
	ld a,b			;8643	78 	x 
	or a			;8644	b7 	. 
	call nz,draw_crlf		;8645	c4 51 86 	. Q . 
	call l80d7h		;8648	cd d7 80 	. . . 
	dec c			;864b	0d 	. 
	ld a,c			;864c	79 	y 
	or a			;864d	b7 	. 
	jr nz,l8639h		;864e	20 e9 	  . 
	ret			;8650	c9 	. 
draw_crlf:
	ld a,020h		;8651	3e 20 	>   
l8653h:
	out (VDP_DATA_PORT),a		;8653	d3 98 	. . 
	djnz l8653h		;8655	10 fc 	. . 
	ret			;8657	c9 	. 
draw_b_chars_from_hl:
	ld a,(hl)			;8658	7e 	~ 
	cp 00dh		;8659	fe 0d 	. . 
	ret z			;865b	c8 	. 
	cp 01ah		;865c	fe 1a 	. . 
	ret z			;865e	c8 	. 
	out (VDP_DATA_PORT),a		;865f	d3 98 	. . 
	inc hl			;8661	23 	# 
	djnz draw_b_chars_from_hl		;8662	10 f4 	. . 
	ret			;8664	c9 	. 
draw_string_until_cr:
	ld de,(window_left_column)		;8665	ed 5b e8 8c 	. [ . . 
	ld a,d			;8669	7a 	z 
	or e			;866a	b3 	. 
	ret z			;866b	c8 	. 
l866ch:
	ld a,(hl)			;866c	7e 	~ 
	cp 01ah		;866d	fe 1a 	. . 
	ret z			;866f	c8 	. 
	cp 00dh		;8670	fe 0d 	. . 
	ret z			;8672	c8 	. 
	dec de			;8673	1b 	. 
	inc hl			;8674	23 	# 
	ld a,d			;8675	7a 	z 
	or e			;8676	b3 	. 
	jr nz,l866ch		;8677	20 f3 	  . 
	ret			;8679	c9 	. 
read_key:
	ld hl,(screen_cursor_ptr)		;867a	2a e2 8c 	* . . 
	call clear_screen_area		;867d	cd f1 86 	. . . 
	ld (scratch_byte_8cfc),a		;8680	32 fc 8c 	2 . . 
l8683h:
	in a,(PPI_PORT_C)		;8683	db aa 	. . 
	and 0f0h		;8685	e6 f0 	. . 
	or 006h		;8687	f6 06 	. . 
	out (PPI_PORT_C),a		;8689	d3 aa 	. . 
	in a,(PPI_PORT_B)		;868b	db a9 	. . 
	ld (saved_char_under_cursor),a		;868d	32 02 8d 	2 . . 
	ld a,(scratch_byte_8cfe)		;8690	3a fe 8c 	: . . 
	dec a			;8693	3d 	= 
	ld (scratch_byte_8cfe),a		;8694	32 fe 8c 	2 . . 
	jr nz,l86aah		;8697	20 11 	  . 
	ld a,(scratch_byte_8cfd)		;8699	3a fd 8c 	: . . 
	cp 023h		;869c	fe 23 	. # 
	jr z,l86a4h		;869e	28 04 	( . 
	ld a,023h		;86a0	3e 23 	> # 
	jr l86a7h		;86a2	18 03 	. . 
l86a4h:
	ld a,(scratch_byte_8cfc)		;86a4	3a fc 8c 	: . . 
l86a7h:
	ld (scratch_byte_8cfd),a		;86a7	32 fd 8c 	2 . . 
l86aah:
	ld a,(scratch_byte_8cfd)		;86aa	3a fd 8c 	: . . 
	ld hl,(screen_cursor_ptr)		;86ad	2a e2 8c 	* . . 
	call poke_char_to_screen_line		;86b0	cd e7 86 	. . . 
	ld c,006h		;86b3	0e 06 	. . 
	ld a,0ffh		;86b5	3e ff 	> . 
	ld e,a			;86b7	5f 	_ 
	call call_bdos_basic		;86b8	cd cf 8c 	. . . 
	di			;86bb	f3 	. 
	or a			;86bc	b7 	. 
	jr z,l8683h		;86bd	28 c4 	( . 
	ld e,a			;86bf	5f 	_ 
	ld a,(scratch_byte_8cfc)		;86c0	3a fc 8c 	: . . 
	ld hl,(screen_cursor_ptr)		;86c3	2a e2 8c 	* . . 
	call poke_char_to_screen_line		;86c6	cd e7 86 	. . . 
	call goto_xy_from_hl		;86c9	cd d4 86 	. . . 
	ld a,e			;86cc	7b 	{ 
	ret			;86cd	c9 	. 
compare_hl_de:
	ld a,h			;86ce	7c 	| 
	sub d			;86cf	92 	. 
	ret nz			;86d0	c0 	. 
	ld a,l			;86d1	7d 	} 
	sub e			;86d2	93 	. 
	ret			;86d3	c9 	. 
goto_xy_from_hl:
	ld a,l			;86d4	7d 	} 
	out (VDP_CONTROL_PORT),a		;86d5	d3 99 	. . 
	ld a,h			;86d7	7c 	| 
	and 03fh		;86d8	e6 3f 	. ? 
	or 040h		;86da	f6 40 	. @ 
l86dch:
	out (VDP_CONTROL_PORT),a		;86dc	d3 99 	. . 
	ret			;86de	c9 	. 
print_a:
	ld a,l			;86df	7d 	} 
	out (VDP_CONTROL_PORT),a		;86e0	d3 99 	. . 
	ld a,h			;86e2	7c 	| 
	and 03fh		;86e3	e6 3f 	. ? 
	jr l86dch		;86e5	18 f5 	. . 
poke_char_to_screen_line:
	push af			;86e7	f5 	. 
	call goto_xy_from_hl		;86e8	cd d4 86 	. . . 
	ex (sp),hl			;86eb	e3 	. 
	ex (sp),hl			;86ec	e3 	. 
	pop af			;86ed	f1 	. 
	out (VDP_DATA_PORT),a		;86ee	d3 98 	. . 
	ret			;86f0	c9 	. 
clear_screen_area:
	call print_a		;86f1	cd df 86 	. . . 
	ex (sp),hl			;86f4	e3 	. 
	ex (sp),hl			;86f5	e3 	. 
	in a,(VDP_DATA_PORT)		;86f6	db 98 	. . 
	ret			;86f8	c9 	. 
exit_editor:
	ret			;86f9	c9 	. 
l86fah:
	jr nz,l871ch		;86fa	20 20 	    
	jr nz,l871eh		;86fc	20 20 	    
	jr nz,l8720h		;86fe	20 20 	    
	jr nz,l8722h		;8700	20 20 	    
	jr nz,l8724h		;8702	20 20 	    
	jr nz,$+34		;8704	20 20 	    
	jr nz,l8728h		;8706	20 20 	    
	jr nz,l872ah		;8708	20 20 	    
	jr nz,l872ch		;870a	20 20 	    
	jr nz,$+34		;870c	20 20 	    
	jr nz,l8730h		;870e	20 20 	    
	jr nz,l8732h		;8710	20 20 	    
	jr nz,l8734h		;8712	20 20 	    
	jr nz,$+34		;8714	20 20 	    
	jr nz,l8738h		;8716	20 20 	    
	jr nz,$+34		;8718	20 20 	    
	jr nz,l873ch		;871a	20 20 	    
l871ch:
	jr nz,l873eh		;871c	20 20 	    
l871eh:
	dec c			;871e	0d 	. 
	sbc a,b			;871f	98 	. 
l8720h:
	inc bc			;8720	03 	. 
l8721h:
	ld b,(hl)			;8721	46 	F 
l8722h:
	ld l,c			;8722	69 	i 
	ld l,h			;8723	6c 	l 
l8724h:
	ld h,l			;8724	65 	e 
	ld a,(09d0dh)		;8725	3a 0d 9d 	: . . 
l8728h:
	inc bc			;8728	03 	. 
l8729h:
	ld b,(hl)			;8729	46 	F 
l872ah:
	ld l,c			;872a	69 	i 
	ld l,(hl)			;872b	6e 	n 
l872ch:
	ld h,h			;872c	64 	d 
	ld a,(09d0dh)		;872d	3a 0d 9d 	: . . 
l8730h:
	inc bc			;8730	03 	. 
l8731h:
	ld d,h			;8731	54 	T 
l8732h:
	ld h,l			;8732	65 	e 
	ld a,b			;8733	78 	x 
l8734h:
	ld (hl),h			;8734	74 	t 
	jr nz,$+112		;8735	20 6e 	  n 
	ld l,a			;8737	6f 	o 
l8738h:
	ld (hl),h			;8738	74 	t 
	jr nz,l87a1h		;8739	20 66 	  f 
	ld l,a			;873b	6f 	o 
l873ch:
	ld (hl),l			;873c	75 	u 
	ld l,(hl)			;873d	6e 	n 
l873eh:
	ld h,h			;873e	64 	d 
	dec c			;873f	0d 	. 
l8740h:
	ld c,c			;8740	49 	I 
	ld l,(hl)			;8741	6e 	n 
	halt			;8742	76 	v 
	ld h,c			;8743	61 	a 
	ld l,h			;8744	6c 	l 
	ld l,c			;8745	69 	i 
	ld h,h			;8746	64 	d 
	jr nz,l878fh		;8747	20 46 	  F 
	ld l,c			;8749	69 	i 
	ld l,h			;874a	6c 	l 
	ld h,l			;874b	65 	e 
	cpl			;874c	2f 	/ 
	ld (hl),e			;874d	73 	s 
	ld (hl),b			;874e	70 	p 
	ld h,l			;874f	65 	e 
	ld h,e			;8750	63 	c 
	ld l,c			;8751	69 	i 
	ld h,(hl)			;8752	66 	f 
	ld l,c			;8753	69 	i 
	ld h,e			;8754	63 	c 
	ld h,c			;8755	61 	a 
	ld (hl),h			;8756	74 	t 
	ld l,c			;8757	69 	i 
	ld l,a			;8758	6f 	o 
	ld l,(hl)			;8759	6e 	n 
	dec c			;875a	0d 	. 
l875bh:
	ld b,e			;875b	43 	C 
	ld l,b			;875c	68 	h 
	ld h,c			;875d	61 	a 
	ld l,(hl)			;875e	6e 	n 
	ld h,a			;875f	67 	g 
	ld h,l			;8760	65 	e 
	ld a,(09f0dh)		;8761	3a 0d 9f 	: . . 
	inc bc			;8764	03 	. 
l8765h:
	ld c,(hl)			;8765	4e 	N 
	ld h,l			;8766	65 	e 
	ld (hl),a			;8767	77 	w 
	jr nz,l87b0h		;8768	20 46 	  F 
	ld l,c			;876a	69 	i 
	ld l,h			;876b	6c 	l 
	ld h,l			;876c	65 	e 
	ld l,02eh		;876d	2e 2e 	. . 
	ld l,00dh		;876f	2e 0d 	. . 
convert_number_to_ascii:
	ld hl,00398h		;8771	21 98 03 	! . . 
	call goto_xy_from_hl		;8774	cd d4 86 	. . . 
	push hl			;8777	e5 	. 
	ld hl,l86fah		;8778	21 fa 86 	! . . 
	ld b,028h		;877b	06 28 	. ( 
	call draw_b_chars_from_hl		;877d	cd 58 86 	. X . 
	pop hl			;8780	e1 	. 
	call goto_xy_from_hl		;8781	cd d4 86 	. . . 
	ret			;8784	c9 	. 
print_decimal_de:
	push hl			;8785	e5 	. 
	call convert_number_to_ascii		;8786	cd 71 87 	. q . 
	pop hl			;8789	e1 	. 
	ld b,028h		;878a	06 28 	. ( 
	call draw_b_chars_from_hl		;878c	cd 58 86 	. X . 
l878fh:
	inc hl			;878f	23 	# 
	ld a,(hl)			;8790	7e 	~ 
	inc hl			;8791	23 	# 
	ld h,(hl)			;8792	66 	f 
	ld l,a			;8793	6f 	o 
	ret			;8794	c9 	. 
decode_numeric_input:
	push hl			;8795	e5 	. 
	ld bc,00013h		;8796	01 13 00 	. . . 
	ld hl,l8d0bh		;8799	21 0b 8d 	! . . 
	ld de,l8d0ch		;879c	11 0c 8d 	. . . 
	ld (hl),020h		;879f	36 20 	6   
l87a1h:
	ldir		;87a1	ed b0 	. . 
	ld hl,(screen_cursor_ptr)		;87a3	2a e2 8c 	* . . 
	ld (screen_line_ptr),hl		;87a6	22 e4 8c 	" . . 
	pop hl			;87a9	e1 	. 
	call print_decimal_de		;87aa	cd 85 87 	. . . 
	ld (screen_cursor_ptr),hl		;87ad	22 e2 8c 	" . . 
l87b0h:
	ld a,013h		;87b0	3e 13 	> . 
	call update_status_line		;87b2	cd be 87 	. . . 
	push hl			;87b5	e5 	. 
	ld hl,(screen_line_ptr)		;87b6	2a e4 8c 	* . . 
	ld (screen_cursor_ptr),hl		;87b9	22 e2 8c 	" . . 
	pop hl			;87bc	e1 	. 
	ret			;87bd	c9 	. 
update_status_line:
	ld hl,l8d0bh		;87be	21 0b 8d 	! . . 
	ld d,h			;87c1	54 	T 
	ld e,l			;87c2	5d 	] 
	ld (hl),020h		;87c3	36 20 	6   
	inc de			;87c5	13 	. 
	ld bc,00013h		;87c6	01 13 00 	. . . 
	ldir		;87c9	ed b0 	. . 
	ld b,a			;87cb	47 	G 
	xor a			;87cc	af 	. 
	ld (case_mode),a		;87cd	32 fa 8c 	2 . . 
	ld hl,l8d0bh		;87d0	21 0b 8d 	! . . 
l87d3h:
	push hl			;87d3	e5 	. 
	push bc			;87d4	c5 	. 
	call read_key		;87d5	cd 7a 86 	. z . 
	pop bc			;87d8	c1 	. 
	pop hl			;87d9	e1 	. 
	cp 00dh		;87da	fe 0d 	. . 
	jr z,l882ch		;87dc	28 4e 	( N 
	cp 008h		;87de	fe 08 	. . 
	jr nz,l8800h		;87e0	20 1e 	  . 
	ld a,(case_mode)		;87e2	3a fa 8c 	: . . 
	sub 001h		;87e5	d6 01 	. . 
	jr c,l87d3h		;87e7	38 ea 	8 . 
	ld (case_mode),a		;87e9	32 fa 8c 	2 . . 
	dec hl			;87ec	2b 	+ 
	ld a,020h		;87ed	3e 20 	>   
	ld (hl),a			;87ef	77 	w 
	push hl			;87f0	e5 	. 
	ld hl,(screen_cursor_ptr)		;87f1	2a e2 8c 	* . . 
	dec hl			;87f4	2b 	+ 
	ld (screen_cursor_ptr),hl		;87f5	22 e2 8c 	" . . 
	inc hl			;87f8	23 	# 
	call poke_char_to_screen_line		;87f9	cd e7 86 	. . . 
	pop hl			;87fc	e1 	. 
	inc b			;87fd	04 	. 
	jr l87d3h		;87fe	18 d3 	. . 
l8800h:
	cp 020h		;8800	fe 20 	.   
	jr c,l8828h		;8802	38 24 	8 $ 
	ld (hl),a			;8804	77 	w 
	inc hl			;8805	23 	# 
	push hl			;8806	e5 	. 
	ld hl,(screen_cursor_ptr)		;8807	2a e2 8c 	* . . 
	call poke_char_to_screen_line		;880a	cd e7 86 	. . . 
	inc hl			;880d	23 	# 
	ld (screen_cursor_ptr),hl		;880e	22 e2 8c 	" . . 
	pop hl			;8811	e1 	. 
	push af			;8812	f5 	. 
	ld a,(case_mode)		;8813	3a fa 8c 	: . . 
	inc a			;8816	3c 	< 
	ld (case_mode),a		;8817	32 fa 8c 	2 . . 
	pop af			;881a	f1 	. 
	djnz l87d3h		;881b	10 b6 	. . 
l881dh:
	ld (last_key),a		;881d	32 00 8d 	2 . . 
	ld hl,l8d0bh		;8820	21 0b 8d 	! . . 
	ld a,(case_mode)		;8823	3a fa 8c 	: . . 
	ld b,a			;8826	47 	G 
	ret			;8827	c9 	. 
l8828h:
	cp 01ch		;8828	fe 1c 	. . 
	jr c,l87d3h		;882a	38 a7 	8 . 
l882ch:
	ld (screen_char_tmp),a		;882c	32 01 8d 	2 . . 
	jr l881dh		;882f	18 ec 	. . 
search_text:
	exx			;8831	d9 	. 
	ld hl,l8d56h		;8832	21 56 8d 	! V . 
	ld de,l8d57h		;8835	11 57 8d 	. W . 
	ld bc,0000ah		;8838	01 0a 00 	. . . 
	ld (hl),020h		;883b	36 20 	6   
	ldir		;883d	ed b0 	. . 
	exx			;883f	d9 	. 
	inc hl			;8840	23 	# 
	ld a,(hl)			;8841	7e 	~ 
	dec hl			;8842	2b 	+ 
	cp 03ah		;8843	fe 3a 	. : 
	ld a,000h		;8845	3e 00 	> . 
	jr nz,l8858h		;8847	20 0f 	  . 
	ld a,(hl)			;8849	7e 	~ 
	inc hl			;884a	23 	# 
	inc hl			;884b	23 	# 
	dec b			;884c	05 	. 
	dec b			;884d	05 	. 
	scf			;884e	37 	7 
	ret z			;884f	c8 	. 
	and 003h		;8850	e6 03 	. . 
	scf			;8852	37 	7 
	ret z			;8853	c8 	. 
	cp 003h		;8854	fe 03 	. . 
	scf			;8856	37 	7 
	ret z			;8857	c8 	. 
l8858h:
	ld de,dma_buffer		;8858	11 55 8d 	. U . 
	ld (de),a			;885b	12 	. 
	inc de			;885c	13 	. 
	ld c,b			;885d	48 	H 
	ld b,008h		;885e	06 08 	. . 
	call case_fold_ascii		;8860	cd 7e 88 	. ~ . 
	call nc,match_search_byte		;8863	d4 91 88 	. . . 
	jr nc,l8870h		;8866	30 08 	0 . 
	ld de,l8d5eh		;8868	11 5e 8d 	. ^ . 
	ld b,003h		;886b	06 03 	. . 
	call case_fold_ascii		;886d	cd 7e 88 	. ~ . 
l8870h:
	ld hl,l8d61h		;8870	21 61 8d 	! a . 
	ld de,l8d62h		;8873	11 62 8d 	. b . 
	ld bc,00017h		;8876	01 17 00 	. . . 
	ld (hl),b			;8879	70 	p 
	ldir		;887a	ed b0 	. . 
	or a			;887c	b7 	. 
	ret			;887d	c9 	. 
case_fold_ascii:
	ld a,c			;887e	79 	y 
	or a			;887f	b7 	. 
	ret z			;8880	c8 	. 
	ld a,(hl)			;8881	7e 	~ 
	inc hl			;8882	23 	# 
	dec c			;8883	0d 	. 
	cp 02eh		;8884	fe 2e 	. . 
	scf			;8886	37 	7 
	ret z			;8887	c8 	. 
	call show_found_position		;8888	cd 9c 88 	. . . 
	ld (de),a			;888b	12 	. 
	inc de			;888c	13 	. 
	djnz case_fold_ascii		;888d	10 ef 	. . 
	or a			;888f	b7 	. 
	ret			;8890	c9 	. 
match_search_byte:
	ld a,(hl)			;8891	7e 	~ 
	inc hl			;8892	23 	# 
	or a			;8893	b7 	. 
	dec c			;8894	0d 	. 
	ret z			;8895	c8 	. 
	cp 02eh		;8896	fe 2e 	. . 
	scf			;8898	37 	7 
	ret z			;8899	c8 	. 
	jr match_search_byte		;889a	18 f5 	. . 
show_found_position:
	cp 061h		;889c	fe 61 	. a 
	ret c			;889e	d8 	. 
	cp 07bh		;889f	fe 7b 	. { 
	ret nc			;88a1	d0 	. 
	res 5,a		;88a2	cb af 	. . 
	ret			;88a4	c9 	. 
command_search:
	ld hl,l8721h		;88a5	21 21 87 	! ! . 
	call decode_numeric_input		;88a8	cd 95 87 	. . . 
	ld a,b			;88ab	78 	x 
	or a			;88ac	b7 	. 
	jp z,editor_start		;88ad	ca 00 80 	. . . 
	call search_text		;88b0	cd 31 88 	. 1 . 
	jr nc,l88cfh		;88b3	30 1a 	0 . 
	jr l88c9h		;88b5	18 12 	. . 
l88b7h:
	call prompt_for_search		;88b7	cd f8 88 	. . . 
	jr nz,l88c9h		;88ba	20 0d 	  . 
	ld (text_end_ptr),hl		;88bc	22 e6 8c 	" . . 
	ld (hl),01ah		;88bf	36 1a 	6 . 
	call copy_current_line_to_scratch		;88c1	cd 5b 89 	. [ . 
	ld hl,l8765h		;88c4	21 65 87 	! e . 
	jr l88cch		;88c7	18 03 	. . 
l88c9h:
	ld hl,l8740h		;88c9	21 40 87 	! @ . 
l88cch:
	jp show_message_at_status		;88cc	c3 8d 8b 	. . . 
l88cfh:
	ld de,(edit_ptr)		;88cf	ed 5b de 8c 	. [ . . 
	call wait_for_keypress		;88d3	cd 8a 89 	. . . 
	jr z,l88b7h		;88d6	28 df 	( . 
	jr c,l88e9h		;88d8	38 0f 	8 . 
	call wait_until_key_released		;88da	cd 80 89 	. . . 
	ld (text_end_ptr),hl		;88dd	22 e6 8c 	" . . 
	call prompt_for_search		;88e0	cd f8 88 	. . . 
	call z,copy_current_line_to_scratch		;88e3	cc 5b 89 	. [ . 
	jp editor_start		;88e6	c3 00 80 	. . . 
l88e9h:
	ld a,01ah		;88e9	3e 1a 	> . 
	ld (de),a			;88eb	12 	. 
	call wait_until_key_released		;88ec	cd 80 89 	. . . 
	ld (text_end_ptr),hl		;88ef	22 e6 8c 	" . . 
	ld hl,l8902h		;88f2	21 02 89 	! . . 
	jp show_message_at_status		;88f5	c3 8d 8b 	. . . 
prompt_for_search:
	ld hl,(edit_ptr)		;88f8	2a de 8c 	* . . 
	ld de,text_buffer_start		;88fb	11 7f 8d 	.  . 
	call compare_hl_de		;88fe	cd ce 86 	. . . 
	ret			;8901	c9 	. 
l8902h:
	ld c,c			;8902	49 	I 
	ld l,(hl)			;8903	6e 	n 
	ld (hl),e			;8904	73 	s 
	ld (hl),l			;8905	75 	u 
	ld h,(hl)			;8906	66 	f 
	ld l,c			;8907	69 	i 
	ld h,e			;8908	63 	c 
	ld l,c			;8909	69 	i 
	ld h,l			;890a	65 	e 
	ld l,(hl)			;890b	6e 	n 
	ld (hl),h			;890c	74 	t 
	jr nz,$+79		;890d	20 4d 	  M 
	ld h,l			;890f	65 	e 
	ld l,l			;8910	6d 	m 
	ld l,a			;8911	6f 	o 
	ld (hl),d			;8912	72 	r 
	ld a,c			;8913	79 	y 
	dec c			;8914	0d 	. 
clear_editor_screen:
	call convert_number_to_ascii		;8915	cd 71 87 	. q . 
	ld hl,00398h		;8918	21 98 03 	! . . 
	call goto_xy_from_hl		;891b	cd d4 86 	. . . 
	ld hl,fcb_work_area		;891e	21 47 8d 	! G . 
	ld b,00eh		;8921	06 0e 	. . 
	call draw_b_chars_from_hl		;8923	cd 58 86 	. X . 
	ret			;8926	c9 	. 
command_save_or_mark_1:
	ld hl,fcb_work_area		;8927	21 47 8d 	! G . 
	ld a,(hl)			;892a	7e 	~ 
	cp 03fh		;892b	fe 3f 	. ? 
	jr z,command_save_or_mark_2		;892d	28 19 	( . 
	ld b,00eh		;892f	06 0e 	. . 
	call search_text		;8931	cd 31 88 	. 1 . 
	jp c,l88c9h		;8934	da c9 88 	. . . 
l8937h:
	ld de,text_buffer_start		;8937	11 7f 8d 	.  . 
	call home_cursor		;893a	cd a8 89 	. . . 
	ld a,(fcb_work_area)		;893d	3a 47 8d 	: G . 
	cp 03fh		;8940	fe 3f 	. ? 
	call z,copy_current_line_to_scratch		;8942	cc 5b 89 	. [ . 
	jp editor_start		;8945	c3 00 80 	. . . 
command_save_or_mark_2:
	ld hl,l8721h		;8948	21 21 87 	! ! . 
	call decode_numeric_input		;894b	cd 95 87 	. . . 
	ld a,b			;894e	78 	x 
	or a			;894f	b7 	. 
	jp z,editor_start		;8950	ca 00 80 	. . . 
	call search_text		;8953	cd 31 88 	. 1 . 
	jp c,l88c9h		;8956	da c9 88 	. . . 
	jr l8937h		;8959	18 dc 	. . 
copy_current_line_to_scratch:
	ld a,(dma_buffer)		;895b	3a 55 8d 	: U . 
	or a			;895e	b7 	. 
	ld a,041h		;895f	3e 41 	> A 
	jr z,l8965h		;8961	28 02 	( . 
	ld a,042h		;8963	3e 42 	> B 
l8965h:
	ld hl,fcb_work_area		;8965	21 47 8d 	! G . 
	ld (hl),a			;8968	77 	w 
	inc hl			;8969	23 	# 
	ld (hl),03ah		;896a	36 3a 	6 : 
	inc hl			;896c	23 	# 
	ld de,l8d56h		;896d	11 56 8d 	. V . 
	ld bc,00008h		;8970	01 08 00 	. . . 
	ex de,hl			;8973	eb 	. 
	ldir		;8974	ed b0 	. . 
	ld a,02eh		;8976	3e 2e 	> . 
	ld (de),a			;8978	12 	. 
	inc de			;8979	13 	. 
	ld bc,00003h		;897a	01 03 00 	. . . 
	ldir		;897d	ed b0 	. . 
	ret			;897f	c9 	. 
wait_until_key_released:
	ld hl,text_buffer_start		;8980	21 7f 8d 	!  . 
l8983h:
	ld a,(hl)			;8983	7e 	~ 
	cp 01ah		;8984	fe 1a 	. . 
	ret z			;8986	c8 	. 
	inc hl			;8987	23 	# 
	jr l8983h		;8988	18 f9 	. . 
wait_for_keypress:
	push de			;898a	d5 	. 
	call bdos_read_sequential		;898b	cd c2 8c 	. . . 
	pop de			;898e	d1 	. 
	inc a			;898f	3c 	< 
	ret z			;8990	c8 	. 
l8991h:
	ld hl,0ad87h		;8991	21 87 ad 	! . . 
	call compare_hl_de		;8994	cd ce 86 	. . . 
	ret c			;8997	d8 	. 
	ld hl,DOS_COMMAND_TAIL		;8998	21 80 00 	! . . 
	add hl,de			;899b	19 	. 
	push hl			;899c	e5 	. 
	call bdos_set_dma		;899d	cd c9 8c 	. . . 
	call bdos_write_sequential		;89a0	cd d2 8c 	. . . 
	pop de			;89a3	d1 	. 
	or a			;89a4	b7 	. 
	jr z,l8991h		;89a5	28 ea 	( . 
	ret			;89a7	c9 	. 
home_cursor:
	push de			;89a8	d5 	. 
	call bdos_create_file		;89a9	cd d6 8c 	. . . 
	pop de			;89ac	d1 	. 
l89adh:
	push de			;89ad	d5 	. 
	call bdos_set_dma		;89ae	cd c9 8c 	. . . 
	call bdos_close_file		;89b1	cd da 8c 	. . . 
	pop de			;89b4	d1 	. 
	ld hl,DOS_COMMAND_TAIL		;89b5	21 80 00 	! . . 
	add hl,de			;89b8	19 	. 
	call compare_de_with_text_end		;89b9	cd c8 80 	. . . 
	jp nc,l8cbeh		;89bc	d2 be 8c 	. . . 
	ex de,hl			;89bf	eb 	. 
	jr l89adh		;89c0	18 eb 	. . 
draw_status_area:
	ld hl,(window_left_column)		;89c2	2a e8 8c 	* . . 
	xor a			;89c5	af 	. 
	ld de,0000ah		;89c6	11 0a 00 	. . . 
l89c9h:
	and a			;89c9	a7 	. 
	sbc hl,de		;89ca	ed 52 	. R 
	jr c,l89d6h		;89cc	38 08 	8 . 
	inc a			;89ce	3c 	< 
	cp 00ah		;89cf	fe 0a 	. . 
	jr c,l89c9h		;89d1	38 f6 	8 . 
	xor a			;89d3	af 	. 
	jr l89c9h		;89d4	18 f3 	. . 
l89d6h:
	ld c,a			;89d6	4f 	O 
	ld hl,00370h		;89d7	21 70 03 	! p . 
	call goto_xy_from_hl		;89da	cd d4 86 	. . . 
	ld a,c			;89dd	79 	y 
	ld b,004h		;89de	06 04 	. . 
l89e0h:
	ld c,a			;89e0	4f 	O 
	push bc			;89e1	c5 	. 
	call draw_memory_counter		;89e2	cd fc 89 	. . . 
	pop bc			;89e5	c1 	. 
	ld a,c			;89e6	79 	y 
	inc a			;89e7	3c 	< 
	cp 00ah		;89e8	fe 0a 	. . 
	jr c,l89edh		;89ea	38 01 	8 . 
	xor a			;89ec	af 	. 
l89edh:
	djnz l89e0h		;89ed	10 f1 	. . 
	ld a,(cursor_column)		;89ef	3a f6 8c 	: . . 
	ld e,a			;89f2	5f 	_ 
	ld d,000h		;89f3	16 00 	. . 
	add hl,de			;89f5	19 	. 
	ld a,024h		;89f6	3e 24 	> $ 
	call poke_char_to_screen_line		;89f8	cd e7 86 	. . . 
	ret			;89fb	c9 	. 
draw_memory_counter:
	add a,030h		;89fc	c6 30 	. 0 
	out (VDP_DATA_PORT),a		;89fe	d3 98 	. . 
	ld a,02dh		;8a00	3e 2d 	> - 
	ld b,009h		;8a02	06 09 	. . 
l8a04h:
	out (VDP_DATA_PORT),a		;8a04	d3 98 	. . 
	djnz l8a04h		;8a06	10 fc 	. . 
	ret			;8a08	c9 	. 
draw_column_counter:
	ld hl,(edit_ptr)		;8a09	2a de 8c 	* . . 
	ld b,008h		;8a0c	06 08 	. . 
	ld c,000h		;8a0e	0e 00 	. . 
	call find_line_start_backward		;8a10	cd f0 80 	. . . 
l8a13h:
	call compare_de_with_text_limit		;8a13	cd d0 80 	. . . 
	jr z,l8a1eh		;8a16	28 06 	( . 
	call find_previous_line		;8a18	cd e5 80 	. . . 
	inc c			;8a1b	0c 	. 
	djnz l8a13h		;8a1c	10 f5 	. . 
l8a1eh:
	ld (window_top_ptr),hl		;8a1e	22 e0 8c 	" . . 
	ld a,c			;8a21	79 	y 
	ld (cursor_row),a		;8a22	32 f7 8c 	2 . . 
	ld hl,00000h		;8a25	21 00 00 	! . . 
	or a			;8a28	b7 	. 
	jr z,l8a32h		;8a29	28 07 	( . 
	ld de,00028h		;8a2b	11 28 00 	. ( . 
	ld b,a			;8a2e	47 	G 
l8a2fh:
	add hl,de			;8a2f	19 	. 
	djnz l8a2fh		;8a30	10 fd 	. . 
l8a32h:
	push hl			;8a32	e5 	. 
	ld hl,(edit_ptr)		;8a33	2a de 8c 	* . . 
	call find_line_start_backward		;8a36	cd f0 80 	. . . 
	ld (line_start_ptr),hl		;8a39	22 ee 8c 	" . . 
	call recompute_window_top		;8a3c	cd 2b 81 	. + . 
	ld a,(line_visible_len)		;8a3f	3a fb 8c 	: . . 
	ld (cursor_column),a		;8a42	32 f6 8c 	2 . . 
	pop hl			;8a45	e1 	. 
	ld d,000h		;8a46	16 00 	. . 
	ld e,a			;8a48	5f 	_ 
	add hl,de			;8a49	19 	. 
	ld (screen_cursor_ptr),hl		;8a4a	22 e2 8c 	" . . 
	ret			;8a4d	c9 	. 
copy_until_linebreak:
	call draw_string_until_cr		;8a4e	cd 65 86 	. e . 
	cp 00dh		;8a51	fe 0d 	. . 
	jr z,l8a78h		;8a53	28 23 	( # 
	cp 01ah		;8a55	fe 1a 	. . 
	jr z,l8a78h		;8a57	28 1f 	( . 
	ld a,(cursor_column)		;8a59	3a f6 8c 	: . . 
	or a			;8a5c	b7 	. 
	jr z,l8a96h		;8a5d	28 37 	( 7 
	ld e,a			;8a5f	5f 	_ 
	ld d,000h		;8a60	16 00 	. . 
	call l866ch		;8a62	cd 6c 86 	. l . 
	ld a,(cursor_column)		;8a65	3a f6 8c 	: . . 
	sub e			;8a68	93 	. 
	ld (cursor_column),a		;8a69	32 f6 8c 	2 . . 
clear_input_buffer:
	push hl			;8a6c	e5 	. 
	ld hl,(screen_cursor_ptr)		;8a6d	2a e2 8c 	* . . 
	sbc hl,de		;8a70	ed 52 	. R 
	ld (screen_cursor_ptr),hl		;8a72	22 e2 8c 	" . . 
	pop hl			;8a75	e1 	. 
	jr l8a96h		;8a76	18 1e 	. . 
l8a78h:
	ld a,(cursor_column)		;8a78	3a f6 8c 	: . . 
	ld d,000h		;8a7b	16 00 	. . 
	ld e,a			;8a7d	5f 	_ 
	call clear_input_buffer		;8a7e	cd 6c 8a 	. l . 
	push hl			;8a81	e5 	. 
	call recompute_window_top		;8a82	cd 2b 81 	. + . 
	ld a,(line_visible_len)		;8a85	3a fb 8c 	: . . 
	ld d,000h		;8a88	16 00 	. . 
	ld e,a			;8a8a	5f 	_ 
	ld (cursor_column),a		;8a8b	32 f6 8c 	2 . . 
	ld hl,(screen_cursor_ptr)		;8a8e	2a e2 8c 	* . . 
	add hl,de			;8a91	19 	. 
	ld (screen_cursor_ptr),hl		;8a92	22 e2 8c 	" . . 
	pop hl			;8a95	e1 	. 
l8a96h:
	ld (edit_ptr),hl		;8a96	22 de 8c 	" . . 
	ret			;8a99	c9 	. 
command_cut_block:
	call remove_semicolon_comment		;8a9a	cd 59 8b 	. Y . 
	ld a,b			;8a9d	78 	x 
	or a			;8a9e	b7 	. 
	jp z,editor_start		;8a9f	ca 00 80 	. . . 
	ld de,l8d1fh		;8aa2	11 1f 8d 	. . . 
	ld a,b			;8aa5	78 	x 
	ld (de),a			;8aa6	12 	. 
	inc de			;8aa7	13 	. 
	ld c,b			;8aa8	48 	H 
	ld b,000h		;8aa9	06 00 	. . 
	ldir		;8aab	ed b0 	. . 
command_mark_block_start:
	ld hl,l8d1fh		;8aad	21 1f 8d 	! . . 
	ld b,(hl)			;8ab0	46 	F 
	inc hl			;8ab1	23 	# 
	call insert_semicolon_comment		;8ab2	cd 60 8b 	. ` . 
	jp c,editor_start		;8ab5	da 00 80 	. . . 
	jp l8b8ah		;8ab8	c3 8a 8b 	. . . 
command_mark_block_end:
	call remove_semicolon_comment		;8abb	cd 59 8b 	. Y . 
	ld a,b			;8abe	78 	x 
	or a			;8abf	b7 	. 
	jp z,editor_start		;8ac0	ca 00 80 	. . . 
	ld de,l8d1fh		;8ac3	11 1f 8d 	. . . 
	ld (de),a			;8ac6	12 	. 
	inc de			;8ac7	13 	. 
	ld c,b			;8ac8	48 	H 
	ld b,000h		;8ac9	06 00 	. . 
	ldir		;8acb	ed b0 	. . 
	ld hl,l875bh		;8acd	21 5b 87 	! [ . 
	call decode_numeric_input		;8ad0	cd 95 87 	. . . 
	ld a,b			;8ad3	78 	x 
	or a			;8ad4	b7 	. 
	jp z,editor_start		;8ad5	ca 00 80 	. . . 
	ld de,l8d33h		;8ad8	11 33 8d 	. 3 . 
	ld (de),a			;8adb	12 	. 
	inc de			;8adc	13 	. 
	ld c,b			;8add	48 	H 
	ld b,000h		;8ade	06 00 	. . 
	ldir		;8ae0	ed b0 	. . 
command_paste_block:
	ld hl,l8d1fh		;8ae2	21 1f 8d 	! . . 
	ld b,(hl)			;8ae5	46 	F 
	inc hl			;8ae6	23 	# 
	call insert_semicolon_comment		;8ae7	cd 60 8b 	. ` . 
	jp nc,l8b8ah		;8aea	d2 8a 8b 	. . . 
	ld de,l8d33h		;8aed	11 33 8d 	. 3 . 
	ld a,(de)			;8af0	1a 	. 
	inc de			;8af1	13 	. 
	ld b,a			;8af2	47 	G 
	call delete_marked_block		;8af3	cd f9 8a 	. . . 
	jp editor_start		;8af6	c3 00 80 	. . . 
delete_marked_block:
	ld hl,l8d1fh		;8af9	21 1f 8d 	! . . 
	ld a,(hl)			;8afc	7e 	~ 
	ld (scratch_byte_8d03),a		;8afd	32 03 8d 	2 . . 
	ld c,b			;8b00	48 	H 
	ld b,000h		;8b01	06 00 	. . 
	ld hl,(edit_ptr)		;8b03	2a de 8c 	* . . 
l8b06h:
	ld a,(scratch_byte_8d03)		;8b06	3a 03 8d 	: . . 
	sub 001h		;8b09	d6 01 	. . 
	jr nc,l8b17h		;8b0b	30 0a 	0 . 
	push hl			;8b0d	e5 	. 
	push de			;8b0e	d5 	. 
	push bc			;8b0f	c5 	. 
	call line_begins_with_comment		;8b10	cd 42 8b 	. B . 
	pop bc			;8b13	c1 	. 
	pop de			;8b14	d1 	. 
	pop hl			;8b15	e1 	. 
	xor a			;8b16	af 	. 
l8b17h:
	ld (scratch_byte_8d03),a		;8b17	32 03 8d 	2 . . 
	ld a,(de)			;8b1a	1a 	. 
	ld (hl),a			;8b1b	77 	w 
	inc hl			;8b1c	23 	# 
	inc de			;8b1d	13 	. 
	ld a,(block_end_ptr)		;8b1e	3a 06 8d 	: . . 
	or a			;8b21	b7 	. 
	jr z,l8b35h		;8b22	28 11 	( . 
	inc de			;8b24	13 	. 
	push hl			;8b25	e5 	. 
	ld hl,(block_end_runtime)		;8b26	2a 07 8d 	* . . 
	inc hl			;8b29	23 	# 
	ld (block_end_runtime),hl		;8b2a	22 07 8d 	" . . 
	ld hl,(block_limit_ptr)		;8b2d	2a 09 8d 	* . . 
	inc hl			;8b30	23 	# 
	ld (block_limit_ptr),hl		;8b31	22 09 8d 	" . . 
	pop hl			;8b34	e1 	. 
l8b35h:
	dec bc			;8b35	0b 	. 
	ld a,b			;8b36	78 	x 
	or c			;8b37	b1 	. 
	jr nz,l8b06h		;8b38	20 cc 	  . 
	ld a,(scratch_byte_8d03)		;8b3a	3a 03 8d 	: . . 
	or a			;8b3d	b7 	. 
	call nz,toggle_semicolon_comment		;8b3e	c4 4e 8b 	. N . 
	ret			;8b41	c9 	. 
line_begins_with_comment:
	push hl			;8b42	e5 	. 
	call has_free_text_space		;8b43	cd fc 81 	. . . 
	pop de			;8b46	d1 	. 
	ld hl,(text_end_ptr)		;8b47	2a e6 8c 	* . . 
	call make_gap_for_insert		;8b4a	cd e3 81 	. . . 
	ret			;8b4d	c9 	. 
toggle_semicolon_comment:
	ld b,a			;8b4e	47 	G 
l8b4fh:
	push hl			;8b4f	e5 	. 
	push bc			;8b50	c5 	. 
	call is_line_boundary_or_eof		;8b51	cd aa 85 	. . . 
	pop bc			;8b54	c1 	. 
	pop hl			;8b55	e1 	. 
	djnz l8b4fh		;8b56	10 f7 	. . 
	ret			;8b58	c9 	. 
remove_semicolon_comment:
	ld hl,l8729h		;8b59	21 29 87 	! ) . 
	call decode_numeric_input		;8b5c	cd 95 87 	. . . 
	ret			;8b5f	c9 	. 
insert_semicolon_comment:
	ld de,(edit_ptr)		;8b60	ed 5b de 8c 	. [ . . 
	ex de,hl			;8b64	eb 	. 
	ld a,(screen_char_tmp)		;8b65	3a 01 8d 	: . . 
	cp 01dh		;8b68	fe 1d 	. . 
	jr z,l8b7ch		;8b6a	28 10 	( . 
	cp 01eh		;8b6c	fe 1e 	. . 
	jr z,l8b7ch		;8b6e	28 0c 	( . 
l8b70h:
	inc hl			;8b70	23 	# 
	ld a,(hl)			;8b71	7e 	~ 
	cp 01ah		;8b72	fe 1a 	. . 
	ret z			;8b74	c8 	. 
	call confirm_prompt		;8b75	cd a1 8b 	. . . 
	jr c,l8b99h		;8b78	38 1f 	8 . 
	jr l8b70h		;8b7a	18 f4 	. . 
l8b7ch:
	dec hl			;8b7c	2b 	+ 
	push de			;8b7d	d5 	. 
	call compare_de_with_text_limit		;8b7e	cd d0 80 	. . . 
	pop de			;8b81	d1 	. 
	ret z			;8b82	c8 	. 
	call confirm_prompt		;8b83	cd a1 8b 	. . . 
	jr c,l8b99h		;8b86	38 11 	8 . 
	jr l8b7ch		;8b88	18 f2 	. . 
l8b8ah:
	ld hl,l8731h		;8b8a	21 31 87 	! 1 . 
show_message_at_status:
	call print_decimal_de		;8b8d	cd 85 87 	. . . 
	ld de,005dch		;8b90	11 dc 05 	. . . 
	call 08caeh		;8b93	cd ae 8c 	. . . 
	jp editor_start		;8b96	c3 00 80 	. . . 
l8b99h:
	ld (edit_ptr),hl		;8b99	22 de 8c 	" . . 
	call draw_column_counter		;8b9c	cd 09 8a 	. . . 
	scf			;8b9f	37 	7 
	ret			;8ba0	c9 	. 
confirm_prompt:
	push bc			;8ba1	c5 	. 
	push de			;8ba2	d5 	. 
	push hl			;8ba3	e5 	. 
l8ba4h:
	ld a,(de)			;8ba4	1a 	. 
	cp (hl)			;8ba5	be 	. 
	jr nz,l8bb1h		;8ba6	20 09 	  . 
	inc hl			;8ba8	23 	# 
	inc de			;8ba9	13 	. 
	djnz l8ba4h		;8baa	10 f8 	. . 
	pop hl			;8bac	e1 	. 
	pop de			;8bad	d1 	. 
	pop bc			;8bae	c1 	. 
	scf			;8baf	37 	7 
	ret			;8bb0	c9 	. 
l8bb1h:
	pop hl			;8bb1	e1 	. 
	pop de			;8bb2	d1 	. 
	pop bc			;8bb3	c1 	. 
	or a			;8bb4	b7 	. 
	ret			;8bb5	c9 	. 
command_toggle_insert_mode:
	ld hl,(text_end_ptr)		;8bb6	2a e6 8c 	* . . 
l8bb9h:
	ld (edit_ptr),hl		;8bb9	22 de 8c 	" . . 
	call draw_column_counter		;8bbc	cd 09 8a 	. . . 
	jp editor_start		;8bbf	c3 00 80 	. . . 
command_toggle_case_mode:
	ld hl,text_buffer_start		;8bc2	21 7f 8d 	!  . 
	jr l8bb9h		;8bc5	18 f2 	. . 
command_comment_line:
	call sub_8bf0h		;8bc7	cd f0 8b 	. . . 
	ld (block_end_runtime),hl		;8bca	22 07 8d 	" . . 
	jp editor_loop		;8bcd	c3 06 80 	. . . 
command_uncomment_line:
	call sub_8bf0h		;8bd0	cd f0 8b 	. . . 
	ld de,(block_end_runtime)		;8bd3	ed 5b 07 8d 	. [ . . 
	call compare_hl_de		;8bd7	cd ce 86 	. . . 
	ld (block_limit_ptr),hl		;8bda	22 09 8d 	" . . 
	jr nc,l8be7h		;8bdd	30 08 	0 . 
	ld hl,00000h		;8bdf	21 00 00 	! . . 
	ld (block_start_ptr),hl		;8be2	22 04 8d 	" . . 
	jr l8bedh		;8be5	18 06 	. . 
l8be7h:
	xor a			;8be7	af 	. 
	sbc hl,de		;8be8	ed 52 	. R 
	ld (block_start_ptr),hl		;8bea	22 04 8d 	" . . 
l8bedh:
	jp editor_loop		;8bed	c3 06 80 	. . . 
sub_8bf0h:
	ld hl,(edit_ptr)		;8bf0	2a de 8c 	* . . 
	ld a,(hl)			;8bf3	7e 	~ 
	cp 00dh		;8bf4	fe 0d 	. . 
	ret nz			;8bf6	c0 	. 
	inc hl			;8bf7	23 	# 
	inc hl			;8bf8	23 	# 
	ret			;8bf9	c9 	. 
command_insert_block_space:
	ld hl,(block_start_ptr)		;8bfa	2a 04 8d 	* . . 
	ld a,h			;8bfd	7c 	| 
	or l			;8bfe	b5 	. 
	jp z,editor_loop		;8bff	ca 06 80 	. . . 
	push hl			;8c02	e5 	. 
	ld hl,(text_end_ptr)		;8c03	2a e6 8c 	* . . 
	ld de,text_buffer_start		;8c06	11 7f 8d 	.  . 
	sbc hl,de		;8c09	ed 52 	. R 
	pop bc			;8c0b	c1 	. 
	add hl,bc			;8c0c	09 	. 
	ld de,02008h		;8c0d	11 08 20 	. .   
	call compare_hl_de		;8c10	cd ce 86 	. . . 
	jr c,l8c1bh		;8c13	38 06 	8 . 
	ld hl,msg_block_too_large		;8c15	21 9d 8c 	! . . 
	jp show_message_at_status		;8c18	c3 8d 8b 	. . . 
l8c1bh:
	ld hl,(edit_ptr)		;8c1b	2a de 8c 	* . . 
	ld de,(block_limit_ptr)		;8c1e	ed 5b 09 8d 	. [ . . 
	dec de			;8c22	1b 	. 
	call compare_hl_de		;8c23	cd ce 86 	. . . 
	jr nc,l8c32h		;8c26	30 0a 	0 . 
	ld de,(block_end_runtime)		;8c28	ed 5b 07 8d 	. [ . . 
	call compare_hl_de		;8c2c	cd ce 86 	. . . 
	jp nc,editor_loop		;8c2f	d2 06 80 	. . . 
l8c32h:
	push bc			;8c32	c5 	. 
	ld de,(text_end_ptr)		;8c33	ed 5b e6 8c 	. [ . . 
	push de			;8c37	d5 	. 
	ex de,hl			;8c38	eb 	. 
	xor a			;8c39	af 	. 
	sbc hl,de		;8c3a	ed 52 	. R 
	pop de			;8c3c	d1 	. 
	push hl			;8c3d	e5 	. 
	ld h,d			;8c3e	62 	b 
	ld l,e			;8c3f	6b 	k 
	add hl,bc			;8c40	09 	. 
	ex de,hl			;8c41	eb 	. 
	pop bc			;8c42	c1 	. 
	inc bc			;8c43	03 	. 
	lddr		;8c44	ed b8 	. . 
	pop bc			;8c46	c1 	. 
	push bc			;8c47	c5 	. 
	ld hl,(edit_ptr)		;8c48	2a de 8c 	* . . 
	ld de,(block_end_runtime)		;8c4b	ed 5b 07 8d 	. [ . . 
	call compare_hl_de		;8c4f	cd ce 86 	. . . 
	jr nc,l8c5ah		;8c52	30 06 	0 . 
	ex de,hl			;8c54	eb 	. 
	add hl,bc			;8c55	09 	. 
	ld (block_end_runtime),hl		;8c56	22 07 8d 	" . . 
	ex de,hl			;8c59	eb 	. 
l8c5ah:
	ex de,hl			;8c5a	eb 	. 
	ldir		;8c5b	ed b0 	. . 
	pop bc			;8c5d	c1 	. 
	ld hl,(text_end_ptr)		;8c5e	2a e6 8c 	* . . 
	add hl,bc			;8c61	09 	. 
	ld (text_end_ptr),hl		;8c62	22 e6 8c 	" . . 
	jp editor_start		;8c65	c3 00 80 	. . . 
draw_block_status:
	ld hl,003b5h		;8c68	21 b5 03 	! . . 
	call goto_xy_from_hl		;8c6b	cd d4 86 	. . . 
	ld de,(block_start_ptr)		;8c6e	ed 5b 04 8d 	. [ . . 
	ld a,d			;8c72	7a 	z 
	or e			;8c73	b3 	. 
	ld hl,msg_no_block		;8c74	21 98 8c 	! . . 
	jr z,l8c8dh		;8c77	28 14 	( . 
	ld hl,(block_limit_ptr)		;8c79	2a 09 8d 	* . . 
	dec hl			;8c7c	2b 	+ 
	dec hl			;8c7d	2b 	+ 
	ld de,(edit_ptr)		;8c7e	ed 5b de 8c 	. [ . . 
	call compare_hl_de		;8c82	cd ce 86 	. . . 
	ld hl,msg_block_active		;8c85	21 93 8c 	! . . 
	jr c,l8c8dh		;8c88	38 03 	8 . 
	ld hl,msg_no_block		;8c8a	21 98 8c 	! . . 
l8c8dh:
	ld b,005h		;8c8d	06 05 	. . 
	call draw_b_chars_from_hl		;8c8f	cd 58 86 	. X . 
	ret			;8c92	c9 	. 
msg_block_active:
	ld b,d			;8c93	42 	B 
	ld l,h			;8c94	6c 	l 
	ld l,a			;8c95	6f 	o 
	ld h,e			;8c96	63 	c 
	ld l,e			;8c97	6b 	k 
msg_no_block:
	dec l			;8c98	2d 	- 
	dec l			;8c99	2d 	- 
	dec l			;8c9a	2d 	- 
	dec l			;8c9b	2d 	- 
	dec l			;8c9c	2d 	- 
msg_block_too_large:
	ld b,d			;8c9d	42 	B 
	ld l,h			;8c9e	6c 	l 
	ld l,a			;8c9f	6f 	o 
	ld h,e			;8ca0	63 	c 
	ld l,e			;8ca1	6b 	k 
	jr nz,l8d18h		;8ca2	20 74 	  t 
	ld l,a			;8ca4	6f 	o 
	ld l,a			;8ca5	6f 	o 
	jr nz,l8d14h		;8ca6	20 6c 	  l 
	ld h,c			;8ca8	61 	a 
	ld (hl),d			;8ca9	72 	r 
	ld h,a			;8caa	67 	g 
	ld h,l			;8cab	65 	e 
	ld hl,0cd0dh		;8cac	21 0d cd 	! . . 
	or a			;8caf	b7 	. 
	adc a,h			;8cb0	8c 	. 
	dec de			;8cb1	1b 	. 
	ld a,d			;8cb2	7a 	z 
	or e			;8cb3	b3 	. 
	jr nz,$-6		;8cb4	20 f8 	  . 
	ret			;8cb6	c9 	. 
	ld b,010h		;8cb7	06 10 	. . 
l8cb9h:
	djnz l8cb9h		;8cb9	10 fe 	. . 
l8cbbh:
	djnz l8cbbh		;8cbb	10 fe 	. . 
	ret			;8cbd	c9 	. 
l8cbeh:
	ld c,010h		;8cbe	0e 10 	. . 
	jr l8cc4h		;8cc0	18 02 	. . 
bdos_read_sequential:
	ld c,00fh		;8cc2	0e 0f 	. . 
l8cc4h:
	ld de,dma_buffer		;8cc4	11 55 8d 	. U . 
	jr call_bdos_basic		;8cc7	18 06 	. . 
bdos_set_dma:
	ld c,01ah		;8cc9	0e 1a 	. . 
	jr call_bdos_basic		;8ccb	18 02 	. . 
	ld c,006h		;8ccd	0e 06 	. . 
call_bdos_basic:
	jp BDOS_BASIC		;8ccf	c3 7d f3 	. } . 
bdos_write_sequential:
	ld c,014h		;8cd2	0e 14 	. . 
	jr l8cc4h		;8cd4	18 ee 	. . 
bdos_create_file:
	ld c,016h		;8cd6	0e 16 	. . 
	jr l8cc4h		;8cd8	18 ea 	. . 
bdos_close_file:
	ld c,015h		;8cda	0e 15 	. . 
	jr l8cc4h		;8cdc	18 e6 	. . 
; Resident editor work area.  Most pointers are initialized here and then updated in RAM.
edit_ptr:
    dw text_buffer_start
window_top_ptr:
    dw text_buffer_start
screen_cursor_ptr:
    dw 0000h
screen_line_ptr:
    dw 0000h
text_end_ptr:
    dw text_buffer_start
window_left_column:
    dw 0000h
visible_line_column:
    dw 0000h
    db 00h, 00h
line_start_ptr:
    dw 0000h
visible_line_ptr:
    dw 0000h
    db 00h, 00h, 00h, 00h
cursor_column:
    db 00h
cursor_row:
    db 00h, 00h
insert_mode:
    db 00h
case_mode:
    db 00h
line_visible_len:
    db 00h
scratch_byte_8cfc:
    db 00h
scratch_byte_8cfd:
    db 23h
scratch_byte_8cfe:
    db 0FFh, 49h
last_key:
    db 00h
screen_char_tmp:
    db 00h
saved_char_under_cursor:
    db 00h
scratch_byte_8d03:
    db 00h
block_start_ptr:
    dw 0000h
block_end_ptr:
    db 00h
block_end_runtime:
    dw 0000h
block_limit_ptr:
    dw 0000h
l8d0bh:
    db 00h
l8d0ch:
    db 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h
l8d14h:
    db 00h, 00h, 00h, 00h
l8d18h:
    db 00h, 00h, 00h, 00h, 00h, 00h, 00h
l8d1fh:
    db 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h
    db 00h, 00h, 00h, 00h
l8d33h:
    db 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h
    db 00h, 00h, 00h, 00h
; FCB/DMA/search scratch space used by file and find commands.
fcb_work_area:
    db 3Fh, 3Ah, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 2Eh, 3Fh, 3Fh, 3Fh
dma_buffer:
    db 0FFh
l8d56h:
    db 00h
l8d57h:
    db 00h, 00h, 00h, 00h, 00h, 00h, 00h
l8d5eh:
    db 00h, 00h, 00h
l8d61h:
    db 00h
l8d62h:
    db 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h
    db 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 0Dh, 0Ah
; Text buffer begins with CP/M EOF marker 1Ah and initial template text.
text_buffer_start:
    db 1Ah, 74h, 00h, 00h, 09h, 09h, 72h, 65h, 74h, 09h, 7Ah, 00h, 00h, 09h, 09h, 64h
    db 65h, 63h, 09h, 68h, 6Ch, 00h, 00h, 09h, 09h, 6Ch, 64h, 09h, 61h, 2Ch, 28h, 68h
    db 6Ch, 29h, 00h, 00h, 09h, 09h, 63h, 70h, 09h, 23h, 32h, 30h, 00h, 00h, 09h, 09h
    db 72h, 65h, 74h, 09h, 7Ah, 00h, 00h, 09h, 09h, 63h, 70h, 09h, 31h, 30h, 00h, 00h
    db 09h, 09h, 72h, 65h, 74h, 09h, 7Ah, 00h, 00h, 09h, 09h, 63h, 61h, 6Ch, 6Ch, 09h
    db 65h, 73h, 71h, 75h, 65h, 72h, 64h, 61h, 00h, 00h, 09h, 09h, 6Ah, 72h, 09h, 70h
    db 61h, 6Ch, 5Fh, 65h, 73h, 71h, 31h, 00h, 00h, 3Bh, 45h, 6Eh, 63h, 6Fh, 6Eh, 74h
    db 72h, 61h, 20h, 6Fh, 20h, 69h, 6Eh, 69h, 63h, 69h, 6Fh, 20h, 64h
    dephase
