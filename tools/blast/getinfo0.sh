#!/bin/bash
BLASTDB=/ifs1/GAG/population/huxuesong/blast/BLASTDB/taxdb:/ifs1/GAG/population/huxuesong/blast/BLASTDB/asndb /ifs1/GAG/population/huxuesong/blast/bin/blastdbcmd -db nt -outfmt "%T|NA|NA|%t|%l" -target_only -entry $1

