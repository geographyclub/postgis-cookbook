/* format csv file */
/* cat allCountries.txt | tr '"' "'" > allCountries.csv */

CREATE TABLE geonames(geonameid int, name text, asciiname text, altnames text, lat float8, lon float8, featureclass text, featurecode text, countrycode text, cc2 text, admin1 text, admin2 text, admin3 text, admin4 text, population bigint, elevation int, dem int, timezone text, mod_date date);
COPY geonames FROM 'allCountries.csv' CSV DELIMITER E'\t';
SELECT AddGeometryColumn('geonames','geom',4326,'POINT',2);
UPDATE geonames SET geom = ST_SetSRID(ST_MakePoint(lon,lat),4326);
CREATE INDEX geonames_geom_idx ON geonames USING GIST ( geom );
ALTER TABLE geonames ADD COLUMN fid serial PRIMARY KEY;
VACUUM ANALYZE geonames;
CLUSTER geonames USING geonames_geom_idx;
ANALYZE geonames;
