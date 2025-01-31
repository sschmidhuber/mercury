PRAGMA journal_mode=wal;

CREATE TABLE "dataset" (
    "id" TEXT,
    "label" TEXT,
    "state" TEXT,
    "timestamp_created" TEXT,
    "timestamp_stagechange" TEXT,
    "retention" INTEGER,
    "hidden" INTEGER,
    "protected" INTEGER,
    "public" INTEGER,
    "downloads" INTEGER,
    PRIMARY KEY("id")
) WITHOUT ROWID, STRICT;

CREATE TABLE "file" (
    "dsid" TEXT,
    "fid" INTEGER,
    "name" TEXT,
    "directory" TEXT,
    "size" INTEGER,
    "type" TEXT,
    "chunks_total" INTEGER,
    "chunks_received" INTEGER,
    "timestamp_created" TEXT,
    "timestamp_uploaded" TEXT,
    FOREIGN KEY("dsid") REFERENCES dataset("id"),
    PRIMARY KEY("dsid", "fid")
) WITHOUT ROWID, STRICT;