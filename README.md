# postgis-cookbook
Cooking with SQL &amp; BASH

Start up

`sudo -u postgres psql`

```
CREATE USER steve;
ALTER USER steve WITH SUPERUSER;
createdb -O steve world
CREATE EXTENSION postgis; CREATE EXTENSION postgis_topology; CREATE EXTENSION postgis_raster; CREATE EXTENSION postgis_sfcgal; CREATE EXTENSION hstore; CREATE extension tablefunc;
```

Set backend

`SET postgis.backend = sfcgal;`

`SET postgis.backend = geos;`

Add user and password

`CREATE ROLE saga LOGIN PASSWORD 'password';`

`GRANT CONNECT ON DATABASE world TO saga;`

`GRANT USAGE ON SCHEMA public TO saga;`

Drop tables with wildcard

```
tables=`psql -d world -P tuples_only=1 -c '\dt' |awk -F" " '/ne_/ {print $3","}'`
psql -d world -c "DROP TABLE ${tables%?};";
```

Get column names

`SELECT column_name FROM information_schema.columns WHERE table_name='state2020' AND column_name LIKE 'zscore%';`

Column to row

`SELECT name, (x).key, (x).value FROM (SELECT name, EACH(hstore(state2020)) AS x FROM state2020) q;`

Add keys, index, cluster

`ALTER TABLE wwf_ecoregion ADD COLUMN fid serial primary key;`

`ALTER TABLE places_nogeom ADD PRIMARY KEY (fid);`

`CREATE INDEX contour100m_poly_gid ON contour100m_poly USING GIST (geom);`

```
VACUUM ANALYZE geosnap;
CLUSTER geosnap USING geosnap_gid;
ANALYZE geosnap;
```

Decompress

`ALTER TABLE allcountries ALTER COLUMN geom SET STORAGE EXTERNAL;`

Add epsg/srid examples (see spatialreference.org)

`INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) values ( 953027, 'esri', 53027, '+proj=eqdc +lat_0=0 +lon_0=0 +lat_1=60 +lat_2=60 +x_0=0 +y_0=0 +a=6371000 +b=6371000 +units=m +no_defs ', 'PROJCS["Sphere_Equidistant_Conic",GEOGCS["GCS_Sphere",DATUM["Not_specified_based_on_Authalic_Sphere",SPHEROID["Sphere",6371000,0]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["Equidistant_Conic"],PARAMETER["False_Easting",0],PARAMETER["False_Northing",0],PARAMETER["Central_Meridian",0],PARAMETER["Standard_Parallel_1",60],PARAMETER["Standard_Parallel_2",60],PARAMETER["Latitude_Of_Origin",0],UNIT["Meter",1],AUTHORITY["EPSG","53027"]]');`

`INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) values ( 954031, 'esri', 54031, '+proj=tpeqd +lat_1=0 +lon_1=0 +lat_2=60 +lon_2=60 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs ', 'PROJCS["World_Two_Point_Equidistant",GEOGCS["GCS_WGS_1984",DATUM["WGS_1984",SPHEROID["WGS_1984",6378137,298.257223563]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["Two_Point_Equidistant"],PARAMETER["False_Easting",0],PARAMETER["False_Northing",0],PARAMETER["Latitude_Of_1st_Point",0],PARAMETER["Latitude_Of_2nd_Point",60],PARAMETER["Longitude_Of_1st_Point",0],PARAMETER["Longitude_Of_2nd_Point",60],UNIT["Meter",1],AUTHORITY["EPSG","54031"]]');`

`INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) values ( 53029, 'ESRI', 53029, '+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m +no_defs ', 'PROJCS["Sphere_Van_der_Grinten_I",GEOGCS["GCS_Sphere",DATUM["Not_specified_based_on_Authalic_Sphere",SPHEROID["Sphere",6371000,0]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["VanDerGrinten"],PARAMETER["False_Easting",0],PARAMETER["False_Northing",0],PARAMETER["Central_Meridian",0],UNIT["Meter",1],AUTHORITY["EPSG","53029"]]');`

Delete rows

`DELETE FROM table;`

Create geometry column

`ALTER TABLE contour10m_dissolve ADD COLUMN geom TYPE GEOMETRY(MULTILINESTRING,4326);`

Make valid

`UPDATE polygon_voronoi SET way = ST_MakeValid(way) WHERE NOT ST_IsValid(way);`

Cast as int with mixed column

`UPDATE ${city}_polygons SET levels = (SELECT CAST(other_tags->'building:levels' AS INT) WHERE other_tags->'building:levels' ~ '^[0-9]+$');`

Change geometry type

`ALTER TABLE milan_point ALTER COLUMN way type geometry(Polygon, 4326);`

`ALTER TABLE limw_points ALTER TABLE contour100m_id TYPE INT USING contour100m_id::integer;`

Geometry collection

`UPDATE places_voronoi set geom = ST_CollectionExtract(ST_VoronoiPolygons(b.geom),3) FROM places b;`

Change srid of multipolygons w/ tolerance error

```
CREATE TABLE urbanareas_3857 AS SELECT * FROM urbanareas;
ALTER TABLE urbanareas_3857 ALTER COLUMN geom type geometry;
UPDATE urbanareas_3857 SET geom = ST_Intersection(ST_MakeEnvelope(-179, -89, 179, 89, 4326),geom);
```

```
CREATE TABLE geonames_3857 AS SELECT * FROM geonames WHERE ST_Contains(ST_MakeEnvelope(-179, -89, 179, 89, 4326),geom);
SELECT UpdateGeometrySRID('hydroriver_simple_3857', 'shape', 3857);
UPDATE hydroriver_simple_3857 SET shape = ST_Transform(ST_SetSRID(shape,4326),3857);
```

Translate/transform

`ALTER TABLE metar_20180320_183305 ADD COLUMN translated geometry(Point,4326);`

`UPDATE metar_20180320_183305 SET translated=ST_SetSrid(ST_Translate(geom,0.1,0),4326);`

Sample raster at points

`UPDATE places a SET dem = ST_Value(r.rast, 1, a.geom) FROM topo15_43200 r WHERE ST_Intersects(r.rast,a.geom);`

List tables from terminal

`psql -d world -c "COPY (SELECT * FROM pg_catalog.pg_tables) TO STDOUT;"`

`psql -d world -c "COPY (SELECT table_name, string_agg(column_name, ', ' order by ordinal_position) as columns FROM information_schema.columns WHERE table_name LIKE 'ne_10m%' GROUP BY table_name;) TO STDOUT"`

Import spatial data
Options: -skipfailures -nlt PROMOTE_TO_MULTI -lco precision=NO --config OGR_GEOMETRY_ACCEPT_UNCLOSED_RING NO

`ogr2ogr -nln countries110m -nlt PROMOTE_TO_MULTI -nlt MULTIPOLYGON -lco precision=NO -overwrite -lco ENCODING=UTF-8 --config PG_USE_COPY YES -f PGDump /vsistdout/ natural_earth_vector.gpkg ne_110m_admin_0_countries | psql -d world -f -`

`ogr2ogr -f PostgreSQL PG:dbname=world wwf_terr_ecos_dissolve.shp -nlt POLYGON -nln wwf_ecoregion`

`shp2pgsql -I -s 4326 simplified_land_polygons.shp simplified_land_polygons | psql -d worldmap`

`raster2pgsql -d -s 4326 -I -C -M topo15_43200.tif -F -t 1x1 topo15_43200 | psql -d world`

Import json

```
\set content `cat factbook.json`
CREATE TABLE factbook ( content jsonb );
INSERT INTO factbook values (:'content');
```

Get json keys

`psql -d world -c "SELECT DISTINCT jsonb_object_keys(tags) FROM highway_primary;"`

Export json keys

`psql -d world -c "COPY (SELECT '<p>' || row_to_json(t) || '</p>' FROM (SELECT a.nameascii, b.station_id, b.temp, b.wind_sp, b.sky FROM places a, metar b WHERE a.metar_id = b.station_id) t) TO STDOUT;" >> $PWD/data/datastream.html;`

Add hstore

`psql -d world -c "ALTER TABLE ${city}_polygons ALTER COLUMN other_tags TYPE hstore USING other_tags::hstore;"`

Convert hstore to text

`psql -d us -c "ALTER TABLE points_${geoid} ALTER COLUMN other_tags TYPE TEXT;"`

Get hstore keys

`psql -d world -c "SELECT DISTINCT skeys(hstore(tags)) FROM planet_osm_polygon;"`

Select hstore keys

`psql -d world -c "UPDATE planet_osm_polygon SET levels = (SELECT tags->'building:levels');"`

`psql -d world -c "SELECT other_tags FROM multipolygons WHERE other_tags LIKE '%construction%';"`

Boolean type

`psql -d world -c "SELECT b.name, COUNT(b.name) FROM points_us a, acs_2019_5yr_place b WHERE ST_Intersects(a.wkb_geometry, b."Shape") AND ((a.other_tags->'%amenity%')::boolean) GROUP BY b.name ORDER BY COUNT(b.name);"`

Replace string

`psql -d world -c "UPDATE <table> SET <field> = replace(<field>, 'cat', 'dog');"`

Concat strings

`psql -d world -c "SELECT CONCAT(b.id,';',b.station,';',b.latitude,';',b.longitude,';',b.elevation) FROM ghcn b WHERE a.fid = b.contour100m_id;"`

Split part

`psql -d world -c "UPDATE countryinfo a SET language1 = b.languagename FROM languagecodes b WHERE SPLIT_PART(regexp_replace(a.languages, '-'||a.iso, '', 'g'), ',', 1) = b.iso_639_1 OR SPLIT_PART(a.languages, ',', 1) = b.iso_639_3;"`

Split + replace

`psql -d world -c "SELECT wx, REGEXP_REPLACE(REGEXP_REPLACE(wx,'(\w\w)','\1 ','g'),' +',' ','g') FROM metar;"`

Copy db to db

`ogr2ogr -overwrite -lco precision=NO --config PG_USE_COPY YES -f PGDump /vsistdout/ PG:dbname=contours fishbase | psql -d gbif -f -`

Copy table to table

`psql -d world -c "CREATE TABLE ne_10m_admin_0_countries_3857 AS TABLE ne_10m_admin_0_countries;"`

Export table to svg files

```
table='ne_10m_admin_0_countries_3857'
psql -d world -c "COPY (SELECT REPLACE(REPLACE(name, ' ', '_'), '.', ''), ST_XMin(geom), (-1 * ST_YMax(geom)), (ST_XMax(geom) - ST_XMin(geom)), (ST_YMax(geom) - ST_YMin(geom)), ST_AsSVG(geom, 1) FROM ${table}) TO STDOUT DELIMITER E'\t'" | while IFS=$'\t' read -a array; do
  echo '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" height="512" width="512" viewBox="'${array[1]}' '${array[2]}' '${array[3]}' '${array[4]}'"><path d="'${array[5]}'" vector-effect="non-scaling-stroke" fill="#FFF" stroke="#000" stroke-width="0.1em" stroke-linejoin="round" stroke-linecap="round"/></svg>' > ${array[0]}.svg
done
```

Export table to one large svg file

```
table='ne_10m_admin_0_countries'
psql -d world -c "COPY (SELECT CONCAT('<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" height=\"512\" width=\"512\" viewBox=\"', CONCAT_WS(' ', ST_XMin(geom), (-1 * ST_YMax(geom)), (ST_XMax(geom) - ST_XMin(geom)), (ST_YMax(geom) - ST_YMin(geom))), '\"><path d=\"', ST_AsSVG(geom, 1), '\" vector-effect=\"non-scaling-stroke\" fill=\"#FFF\" stroke=\"#000\" stroke-width=\"1em\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/>') FROM ${table}) TO STDOUT"
```

Export to ogr

`ogr2ogr -overwrite -f "SQLite" -dsco SPATIALITE=YES avh.sqlite PG:dbname=contours avh`

`pgsql2shp -f "test" -u steve weather "SELECT metar.station_id,metar.temp_c,ST_MakeLine(metar.geom,metar.translated) FROM metar_20180320_183305 AS metar;"`

Export to csv

`psql -d grids -c "COPY (SELECT fid,scalerank,name,adm1name,round(longitude::numeric,2),round(latitude::numeric,2) FROM places) TO STDOUT WITH CSV DELIMITER '|';" > places.csv`

`psql -d world -c "COPY (SELECT fid, wikidata_id, enwiki_title FROM unum WHERE enwiki_title IS NOT NULL) TO STDOUT WITH CSV DELIMITER E'\t';" > unum_wiki.csv`

Export geonames example

`ogr2ogr -overwrite -update -f "SQLite" -sql "SELECT a.featurecode_name, a.featureclass, (SELECT b.geom FROM contour10m_segments1_5 AS b ORDER BY b.geom <-> ST_GeometryN(ST_Collect(a.geom),1) LIMIT 1) FROM allcountries AS a WHERE a.geom && ST_MakeEnvelope(-123,41,-111,51) AND a.featureclass IN ('T','H','U','V') GROUP BY a.featurecode_name, a.featureclass" gbif_bc.sqlite -nln geonames -nlt LINESTRING PG:"dbname=topo15"`

Export gbif first instance as line example

```
extent="-123,41,-111,51"
ogr2ogr -overwrite -f "SQLite" -dsco SPATIALITE=YES -sql "SELECT a.vname_en, a.datasetkey, a.kingdom, a.phylum, a.class, a.order, a.family, a.genus, a.species, a.scientificname, (SELECT b.geom FROM contour10m_seg1_5 AS b ORDER BY b.geom <-> ST_GeometryN(ST_Collect(a.geom),1) LIMIT 1) FROM nmnh AS a WHERE a.geom && ST_MakeEnvelope(${extent}) GROUP BY a.vname_en, a.datasetkey, a.kingdom, a.phylum, a.class, a.order, a.family, a.genus, a.species, a.scientificname" gbif_extract.sqlite -nln gbif -nlt LINESTRING PG:"dbname=contours"
```

Export gbif one-to-many points example

```
extent="-123,41,-111,51"
ogr2ogr -overwrite -f "SQLite" -dsco SPATIALITE=YES -sql "SELECT a.geom, a.vname_en, a.datasetkey, a.kingdom, a.phylum, a.class, a.order, a.family, a.genus, a.species, a.scientificname, (SELECT CAST(b.fid AS int) AS contourid FROM contour10m_seg1_5 AS b ORDER BY b.geom <-> a.geom LIMIT 1) FROM nmnh AS a WHERE a.geom && ST_MakeEnvelope(${extent})" gbif_extract.sqlite -nln gbif -nlt POINT PG:"dbname=contours"
```

