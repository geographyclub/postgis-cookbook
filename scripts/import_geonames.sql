/* import geonames */
-- cat allCountries.txt | tr '"' "'" > allCountries.csv
CREATE TABLE allcountries(geonameid int, name text, asciiname text, altnames text, lat float8, lon float8, featureclass text, featurecode text, countrycode text, cc2 text, admin1 text, admin2 text, admin3 text, admin4 text, population bigint, elevation int, dem int, timezone text, mod_date date);
COPY allcountries FROM 'allCountries.csv' CSV DELIMITER E'\t';
SELECT AddGeometryColumn('allcountries','wkb_geometry',4326,'POINT',2);
ALTER TABLE allcountries ALTER COLUMN wkb_geometry SET STORAGE EXTERNAL;
UPDATE allcountries SET wkb_geometry = ST_SetSRID(ST_MakePoint(lon,lat),4326);
CREATE INDEX allcountries_wkb_geometry_geom_idx ON allcountries USING GIST ( wkb_geometry );
ALTER TABLE allcountries ADD COLUMN ogc_fid serial PRIMARY KEY;
VACUUM ANALYZE allcountries;
CLUSTER allcountries USING allcountries_wkb_geometry_geom_idx;
ANALYZE allcountries;

/* import featurecodes */
CREATE TABLE featurecode_en(featurecode text, name text, notes text);
COPY featurecode_en FROM 'featureCodes_en.txt' DELIMITER E'\t';
ALTER TABLE allcountries ADD COLUMN fcode_en_name text;
UPDATE allcountries a SET fcode_en_name = b.name FROM featurecode_en b WHERE concat(a.featureclass, '.', a.featurecode) = b.featurecode;
ALTER TABLE allcountries ADD COLUMN fcode_en_desc text;
UPDATE allcountries a SET fcode_en_desc = b.notes FROM featurecode_en b WHERE concat(a.featureclass, '.', a.featurecode) = b.featurecode;

/* process languages */
-- csvcut -t --columns=16 countryInfo.txt | tr -d '"' > countryInfo_languages.txt
ALTER TABLE countryinfo ADD COLUMN lang1_label text;
UPDATE countryinfo a SET lang1_label = 'name_' || b.iso_639_1 FROM languagecodes b WHERE a.language1 = b.languagename;
echo $(psql -d world -c "\COPY (SELECT DISTINCT(iso_639_1) FROM places) TO STDOUT;") | tr ' ' '\n' | while read lang; do echo 'UPDATE places SET localname = name_'${lang} WHERE iso_639_1 = ${lang}; done

/* import (manual) */
CREATE TABLE countryinfo(iso text, iso3 text, iso_numeric int, fips text, country text, capital text, area float, population int, continent text, tld text, currencycode text, currencyname text, phone text, postalcodeformat text, postalcoderegex text, languages text, geonameid int, neighbours text, equivalentfips text);
COPY countryinfo FROM 'countryInfo.txt' DELIMITER E'\t';
/* import alternate names */
CREATE TABLE alternatenames(alternatenameid int, geonameid int, isolanguage text, alternatename text, ispreferredname text, isshortname text, iscolloquial text, ishistoric text, date_from text, date_to text);
COPY alternatenames FROM 'alternateNamesV2.txt' DELIMITER E'\t';
/* import iso language */
CREATE TABLE languagecodes(iso_639_3 text, iso_639_2 text, iso_639_1 text, languagename text);
COPY languagecodes FROM 'iso-languagecodes.txt' DELIMITER E'\t' CSV HEADER;

/* join */
ALTER TABLE allcountries ADD COLUMN languagename text;
UPDATE allcountries a SET languagename = regexp_replace(regexp_replace(b.languages, '\-.*$', ''),',.*$','') FROM countryinfo b WHERE a.countrycode = b.iso;
ALTER TABLE allcountries ADD COLUMN localname text;
UPDATE allcountries a SET localname = b.alternatename FROM alternatenames b WHERE a.geonameid = b.geonameid AND a.languagename = b.isolanguage;
