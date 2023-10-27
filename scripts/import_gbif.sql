/* import gbif */

/* rename badname */
-- sed -i '1 s/order/ordername/' ibol.csv

/* import vernacularname */
CREATE TABLE vernacularname(taxonid int, vernacularname varchar, language varchar, country varchar, countryCode varchar, sex varchar, lifestage varchar, source varchar);
COPY vernacularname FROM 'VernacularName.tsv' DELIMITER E'\t' CSV HEADER;
CREATE TABLE vernacularname_agg AS SELECT taxonid,string_agg(vernacularname,';') FROM vernacularname GROUP BY taxonid;

/* import distribution */
-- sed -i 's/"//g' Distribution.tsv
CREATE TABLE distribution(
taxonid int, locationid text, locality text, country text, countrycode text, locationremarks text, establishmentmeans text, lifestage text, occurrencestatus text, threatstatus text, source text);
COPY distribution FROM 'Distribution.tsv' DELIMITER E'\t' CSV HEADER;
CREATE TABLE ibol(gbifid bigint, datasetkey text, occurrenceid text, kingdom text, phylum text, class text, ordername text, family text, genus text, species text, infraspecificepithet text, taxonrank text, scientificname text, countrycode text, locality text, publishingorgkey text, decimallatitude float8, decimallongitude float8, coordinateuncertaintyinmeters float8, coordinateprecision float8, elevation float8, elevationaccuracy float8, depth float8, depthaccuracy float8, eventdate date, day int, month int, year int, taxonkey int, specieskey int, basisofrecord text, institutioncode text, collectioncode text, catalognumber text, recordnumber text, identifiedby text, dateidentified text, license text, rightsholder text, recordedby text, typestatus text, establishmentmeans text, lastinterpreted text, mediatype text, issue text);
COPY ibol FROM 'ibol.csv' DELIMITER E'\t' CSV HEADER;
ALTER TABLE ibol ADD PRIMARY KEY (gbifid);
ALTER TABLE ibol ADD COLUMN wkb_geometry GEOMETRY(POINT, 4326);
ALTER TABLE ibol ALTER COLUMN wkb_geometry SET STORAGE EXTERNAL;
UPDATE ibol SET wkb_geometry = ST_SetSrid(ST_MakePoint(decimallongitude, decimallatitude), 4326);
CREATE INDEX ibol_gid ON ibol USING GIST (wkb_geometry);

/* join */
ALTER TABLE ibol ADD COLUMN vernacularname text;
UPDATE ibol a SET vernacularname = b.string_agg FROM vernacularname_agg b WHERE b.taxonid = a.taxonkey;
