/*

   HSP.h		BWTBlastn functions

   This module contains miscellaneous BWTBlastn functions.

   Copyright (C) 2004, Wong Chi Kwong.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

*/

#ifndef __HSP_H__
#define __HSP_H__

#include "TypeNLimit.h"
#include "MemManager.h"
#include "TextConverter.h"

#define ALPHABET_SIZE				4
#define BIT_PER_CHAR				2
#define CHAR_PER_128				64
#define CHAR_PER_WORD				16
#define CHAR_PER_BYTE				4

#define OUTPUT_PAIRWISE				0
#define OUTPUT_WITH_IDENTITIES		1
#define OUTPUT_NO_IDENTITIES		2
#define OUTPUT_FLAT_WITH_IDENTITIES	3
#define OUTPUT_FLAT_NO_IDENTITIES	4
#define OUTPUT_BLUNT_ENDS			5
#define OUTPUT_FLAT_BLUNT_ENDS		6
#define OUTPUT_XML					7
#define OUTPUT_TABULAR				8
#define OUTPUT_TABULAR_COMMENT		9
#define OUTPUT_ASN_TEXT				10
#define OUTPUT_ASN_BINARY			11

#define QUERY_POS_STRAND	1
#define QUERY_NEG_STRAND	2
#define QUERY_BOTH_STRAND	3

#define CONTEXT_BIT				4
#define CONTEXT_MASK			0x0FFFFFFF

#define MAX_ALIGNMENT_LENGTH	131072
#define SHORTEST_CHR	70

typedef struct _ChrBlock{
	int ref_id;
	unsigned int blockStart;
	unsigned int blockEnd;
	unsigned int ori;
}ChrBlock;

typedef struct _NewAnnotation{
	char chrName[MAX_SEQ_NAME_LENGTH];
	int nameLen;
	unsigned int chrStart;
	unsigned int chrEnd;
	int blockNum;
	ChrBlock *blockInChr;
}NewAnnotation;

typedef struct __ref_anno_t{
	unsigned total_char;
	int chr_num;
	char **chr_name;
	int total_block;
	ChrBlock *block_list;
}ref_anno_t;


//-end

typedef struct HSPUngappedExtLookupTable {
	char maxScore;
	unsigned char maxScorePos;
	char finalScore;
	unsigned char matchMismatchBitVector;	//	In entries where even bit = match/mismatch, odd bit = 0	-> matchMismatchBitVector is even bit compacted
									//	In entries where odd bit = match/mismatch, even bit = 0	-> matchMismatchBitVector is odd bit compacted and then reversed
									//  When all bits are 0, both above case can be handled without problem
} HSPUngappedExtLookupTable;

typedef struct HitList {		// Information of hits generated
	unsigned int posText;				// position in text
	unsigned int info;					// extra hit information
} HitList;

typedef struct HitListWithPosQuery {		// Information of hits generated
	unsigned int posText;				// position in text
	unsigned int posQuery;				// position in query
} HitListWithPosQuery;

typedef struct HitListWithPosQueryLengthError {// Information of hits generated
	unsigned int posText;				// position in text
	unsigned posQuery : 16;		// position in query
	unsigned length   : 8;		// length of hit
	unsigned error    : 8;		// error in hit
} HitListWithPosQueryLengthError;

typedef struct GappedHitList {
	unsigned int posText;		// position in text
	unsigned int posQuery;		// position in query
	unsigned int lengthText;	// length of aligned text
	unsigned int lengthQuery;	// length of aligned query
	int score;					// score of hit
	unsigned int dbSeqIndex;	// DB sequence
	unsigned int ungappedPosText;	// position in text before gapped extension
	unsigned int ungappedPosQuery;	// position in query before gapped extension
} GappedHitList;

typedef struct GappedHitListWithAlignment {
	unsigned int posText;		// position in text
	unsigned int posQuery;		// position in query
	unsigned int lengthText;	// length of aligned text
	unsigned int lengthQuery;	// length of aligned query
	int score;					// score of alignment
	unsigned int dbSeqIndex;	// DB sequence
	unsigned int alignmentOffset;		// alignment; 2 bit per alignment for match, mismatch or ambigurous, insert, delete; offset to a memory pool
	unsigned int auxiliaryTextOffset;	// text characters for mismatch, insert and ambigurous characters; offset to a memory pool
} GappedHitListWithAlignment;

typedef struct Context {
	int contextNum;
	int numOfHit;
	int numOfDPPoint;
	int numOfFinalHit;
	GappedHitListWithAlignment *gappedHitList;
} Context;

typedef struct ContextInfo {
	int reversed;
	int complemented;
	char name[16];
} ContextInfo;

typedef struct Annotation {
	int gi;
	char text[MAX_SEQ_NAME_LENGTH+1];
} Annotation;

typedef struct SeqOffset {
	unsigned int startPos;
	unsigned int endPos;
	int firstAmbiguityIndex;	// The index for the first ambiguity that starts on or after the sequence
	int lastAmbiguityIndex;		// The index for the last ambiguity that ends on or before the sequence
} SeqOffset;

typedef struct Ambiguity {
	unsigned int startPos;
	unsigned int rightOfEndPos;
	int symbol;
} Ambiguity;

typedef struct Traceback {
	unsigned indexDiff			: 20;	// the difference in traceback index for the logical cell directly above
	unsigned textChar			: 4;
	unsigned queryChar			: 4;	// only filled when match/mismatch
	unsigned DOpen				: 1;
	unsigned IOpen				: 1;
	unsigned alignment			: 2;
} Traceback;

typedef struct HSP {
	unsigned int* packedDNA;
	unsigned long long *ubit64_packedDNA;
	int numOfSeq;
	Annotation* annotation;
	SeqOffset* seqOffset;
	int numOfAmbiguity;
	Ambiguity* ambiguity;
	unsigned int dnaLength;
	unsigned int minSeqLength;
} HSP;

typedef struct DPCell {
	int B;	// Best score
	int I;	// Score with insertion
	unsigned int P;	// Logical index of the cell
} DPCell;

typedef struct DPMaxScore {
	int score;
	int tracebackIndex;
	unsigned int posText;
	unsigned int posQuery;
} DPMaxScore;

typedef struct Histogram {
	double minEvalue;
	double maxEvalue;
	int histogramSize;
	int *count;
} Histogram;


#define MAX_SEQ_NAME_LENGTH				256

#define MAX_HISTO_SIZE					256

#define INVALID_CHAR_INDEX				15

#define DP_MATCH_MISMATCH	0	// 0000
#define DP_INSERT			2	// 0010
#define DP_DELETE			3	// 0011
#define DP_INSERT_OPEN		4	// 0100
#define DP_DELETE_OPEN		8	// 1000

#define DP_MASK				3	// 0011

#define DP_INSERT_EXTEND	0	// 0000
#define DP_DELETE_EXTEND	0	// 0000

#define DP_NEG_INFINITY				-1073741824		// use -(2^30) to leave room for decreasing the value without overflow

#define ALIGN_MATCH					0
#define ALIGN_MISMATCH_AMBIGUITY	1
#define ALIGN_INSERT				2
#define ALIGN_DELETE				3

#define ALIGN_PER_WORD				16
#define ALIGN_BIT					2

#define AUX_TEXT_PER_WORD			8
#define AUX_TEXT_BIT				4

static const char lowercaseDnaCharIndex = 14;	// Seems that BLAST treat masked characters as 'N' (still have 1/4 chance of matching)
static const char nonMatchDnaCharIndex  = 15;
static const char dnaChar[16]			= {'A', 'C', 'G', 'T', 'M', 'R', 'S', 'V', 'W', 'Y', 'H', 'K', 'D', 'B', 'N', 'L'};
static const char dnaComplement[16]		= {'T', 'G', 'C', 'A', 'K', 'Y', 'S', 'B', 'W', 'R', 'D', 'M', 'H', 'V', 'N', 'L'};
static const char ambiguityCount[16]    = { 1 ,  1 ,  1 ,  1 ,  2 ,  2 ,  2 ,  3 ,  2 ,  2 ,  3 ,  2 ,  3 ,  3 ,  4 ,  0 };
static const char ambiguityMatch[16][4] = {0, 0, 0, 0,
										   1, 0, 0, 0,
										   2, 0, 0, 0,
										   3, 0, 0, 0,
										   0, 1, 0, 0,
										   0, 2, 0, 0,
										   1, 2, 0, 0,
										   0, 1, 2, 0,
										   0, 3, 0, 0,
										   1, 3, 0, 0,
										   0, 1, 3, 0,
										   2, 3, 0, 0,
										   0, 2, 3, 0,
										   1, 2, 3, 0,
										   0, 1, 2, 3,
										   0, 0, 0, 0};

// Map must be allocated with char[256]
void HSPFillCharMap(unsigned char charMap[255]);
void HSPFillComplementMap(unsigned char complementMap[255]);

// scoringMatrix must be allocated with scoringMatrix[16][16]
void HSPFillScoringMatrix(int scoringMatrix[16][16], const int matchScore, const int mismatchScore, const int leftShift);

HSP *HSPLoad(MMPool *mmPool, const char *PackedDNAFileName, const char *AnnotationFileName, const char *AmbiguityFileName);
HSP *HSPConvertFromText(MMPool *mmPool, const unsigned char *text, const unsigned int textLength,
						const unsigned int FASTARandomSeed, const int maskLowerCase,
						const int gi, const char *seqName);
void HSPFree(MMPool *mmPool, HSP *hsp);

unsigned int HSPParseFASTAToPacked(const char *, const char *, const char *, const char *, const char *, const unsigned int , const int);
unsigned int HSPPackedToFASTA(const char* FASTAFileName, const char* annotationFileName, const char* packedDNAFileName, const char* ambiguityFileName);


#endif
