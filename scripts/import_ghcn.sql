/* import ghcn */

/* convert */
-- ./ghcn2csv-converter.py -f daily -i ghcnd_gsn.dly -o ghcnd_gsn.csv
-- cat ghcnd-stations.txt | awk -v OFS='\t' '{print substr($0,1,12), substr($0,13,8), substr($0,22,9), substr($0,32,6), substr($0,39,2), substr($0,42,30), substr($0,73,3), substr($0,77,3), substr($0,81,5)}' | sed 's/ *\t */\t/g' > ghcnd-stations.csv

/* import */
CREATE TABLE ghcn(id varchar,year integer,month integer,element varchar,value1 Integer,mflag1 varchar,qflag1 varchar,sflag1 varchar,value2 integer,mflag2 varchar,qflag2 varchar,sflag2 varchar,value3 integer,mflag3 varchar,qflag3 varchar,sflag3 varchar,value4 integer,mflag4 varchar,qflag4 varchar,sflag4 varchar,value5 integer,mflag5 varchar,qflag5 varchar,sflag5 varchar,value6 integer,mflag6 varchar,qflag6 varchar,sflag6 varchar,value7 integer,mflag7 varchar,qflag7 varchar,sflag7 varchar,value8 integer,mflag8 varchar,qflag8 varchar,sflag8 varchar,value9 integer,mflag9 varchar,qflag9 varchar,sflag9 varchar,value10 integer,mflag10 varchar,qflag10 varchar,sflag10 varchar,value11 integer,mflag11 varchar,qflag11 varchar,sflag11 varchar,value12 integer,mflag12 varchar,qflag12 varchar,sflag12 varchar,value13 integer,mflag13 varchar,qflag13 varchar,sflag13 varchar,value14 integer,mflag14 varchar,qflag14 varchar,sflag14 varchar,value15 integer,mflag15 varchar,qflag15 varchar,sflag15 varchar,value16 integer,mflag16 varchar,qflag16 varchar,sflag16 varchar,value17 integer,mflag17 varchar,qflag17 varchar,sflag17 varchar,value18 integer,mflag18 varchar,qflag18 varchar,sflag18 varchar,value19 integer,mflag19 varchar,qflag19 varchar,sflag19 varchar,value20 integer,mflag20 varchar,qflag20 varchar,sflag20 varchar,value21 integer,mflag21 varchar,qflag21 varchar,sflag21 varchar,value22 integer,mflag22 varchar,qflag22 varchar,sflag22 varchar,value23 integer,mflag23 varchar,qflag23 varchar,sflag23 varchar,value24 integer,mflag24 varchar,qflag24 varchar,sflag24 varchar,value25 integer,mflag25 varchar,qflag25 varchar,sflag25 varchar,value26 integer,mflag26 varchar,qflag26 varchar,sflag26 varchar,value27 integer,mflag27 varchar,qflag27 varchar,sflag27 varchar,value28 integer,mflag28 varchar,qflag28 varchar,sflag28 varchar,value29 integer,mflag29 varchar,qflag29 varchar,sflag29 varchar,value30 integer,mflag30 varchar,qflag30 varchar,sflag30 varchar,value31 integer,mflag31 varchar,qflag31 varchar,sflag31 varchar);
COPY ghcn FROM 'ghcnd_gsn.csv' DELIMITER ',' CSV HEADER;
ALTER TABLE ghcn ADD COLUMN ogc_fid serial primary key, ADD COLUMN station varchar, ADD COLUMN latitude real, ADD COLUMN longitude real, ADD COLUMN elevation real, ADD COLUMN wkb_geometry GEOMETRY(POINT, 4326);
ALTER TABLE ghcn ALTER COLUMN wkb_geometry SET STORAGE EXTERNAL;
# stations
CREATE TABLE stations(id varchar, latitude real, longitude real, elevation real, state varchar, name varchar, gsn_flag varchar, hcn_flag varchar, wmo_id varchar);
COPY stations FROM 'ghcnd-stations.csv' DELIMITER E'\t';
ALTER TABLE stations ADD COLUMN wkb_geometry GEOMETRY(POINT, 4326);
UPDATE stations SET wkb_geometry = ST_SetSrid(ST_MakePoint(longitude, latitude), 4326);
# join
UPDATE ghcn a SET station = b.name FROM stations b WHERE a.id = b.id;
UPDATE ghcn a SET latitude = b.latitude FROM stations b WHERE a.id = b.id;
UPDATE ghcn a SET longitude = b.longitude FROM stations b WHERE a.id = b.id;
UPDATE ghcn a SET elevation = b.elevation FROM stations b WHERE a.id = b.id;
UPDATE ghcn SET wkb_geometry = ST_SetSrid(ST_MakePoint(longitude, latitude), 4326);
CREATE INDEX ghcn_gid ON ghcn USING GIST (wkb_geometry);
