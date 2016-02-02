# Structure

Beginning padding:

```
00000000: 0000 baba baba baba baba baba baba baba  ................
00000010: baba baba baba baba 0000 baba baba baba  ................
00000020: baba baba baba baba baba baba baba baba  ................
```

Repeated `n` times (in this case looks like 4?)

## Expressions

```
00000070: xxxx xxxx xxxx xxxx e378 0018 0042 0008  .........x...B..
00000080: ffff ffff 0000 0039
```

`0xE378`: "salt" (function identifier?)
`0x0018`: function call (`unit` in this case)
`0x0042`: expression return type (`unit` again)
`0x0008`: expression type
