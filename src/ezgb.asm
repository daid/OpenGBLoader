SECTION "ezgb-header", ROM0[$0100]
    jr entry
    ds $0150 - @
entry:
    halt
    jr entry
