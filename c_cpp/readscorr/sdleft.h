// by Hu Xuesong
#ifndef _G_SDLEFT_H
#define _G_SDLEFT_H

#include <stdint.h>

#define HASH_LENB 128u
#define SDLA_ITEMARRAY 32u

typedef unsigned int uint128_t __attribute__((mode(TI)));

typedef struct __SDLeftArray_t {
    unsigned char CountBit, rBit, ArrayBit;
    unsigned char itemByte; //, HashCnt;
    size_t ArraySize;
    //uint64_t maxCount; == Item_CountBitMask
    //unsigned char ArrayCount;
    uint64_t ItemInsideAll, CellOverflowCount, CountBitOverflow; // ItemInsideAll = ItemInsideArray + CellOverflowCount
    double FalsePositiveRatio;
    void *pDLA, *pextree;
    //uint64_t *outhash;
    uint64_t outhash[2];    // both ArrayBit and rBit is (0,64], so HashCnt==1 for MurmurHash3_x64_128
    uint128_t Item_rBitMask;
    uint64_t Hash_ArrayBitMask, Hash_rBitMask, Item_CountBitMask;
} SDLeftArray_t;

/*
#ifndef KMER_T
#define KMER_T
typedef struct __dbitseq_t {
    size_t l, m;
    char *s;
} dBitSeq_t;
#endif
*/

SDLeftArray_t *dleft_arrayinit(unsigned char CountBit, unsigned char rBit, size_t ArraySize);
size_t dleft_insert_read(unsigned int k, char const *const inseq, size_t len, SDLeftArray_t *dleftobj);

void fprintSDLAnfo(FILE *stream, const SDLeftArray_t * dleftobj);
void dleft_arraydestroy(SDLeftArray_t * const dleftobj);

#endif /* sdleft.h */

