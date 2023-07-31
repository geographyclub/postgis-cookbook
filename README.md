# postgis-cookbook

Useful commands for working with spatial data in psql and bash.

## TABLE OF CONTENTS

1. [Starting out](#Starting-out)  
2. [Importing](#Importing)  
3. [Exporting](#Exporting)
4. [Basic operations](#Basic-operations)
5. [Spatial operations](#Spatial-operations)
6. [Dataset examples](#Dataset-examples)

## Starting out

Sign in for the first time

`sudo -u postgres psql`

Create db

```
CREATE USER steve;
ALTER USER steve WITH SUPERUSER;
createdb -O steve world
CREATE EXTENSION postgis; CREATE EXTENSION postgis_topology; CREATE EXTENSION postgis_raster; CREATE EXTENSION postgis_sfcgal; CREATE EXTENSION hstore; CREATE extension tablefunc;
```

Add user and password

```
CREATE ROLE saga LOGIN PASSWORD 'password';
GRANT CONNECT ON DATABASE world TO saga;
GRANT USAGE ON SCHEMA public TO saga;
```

Set backend

```
SET postgis.backend = sfcgal;
SET postgis.backend = geos;
```

## Importing

Import vector

```
#===============================================
# Some useful options:  						
# -skipfailures  								
# -nlt PROMOTE_TO_MULTI  						
# -lco precision=NO  							
# --config OGR_GEOMETRY_ACCEPT_UNCLOSED_RING NO	
#===============================================

# from file
ogr2ogr -f PostgreSQL PG:dbname=world wwf_terr_ecos_dissolve.shp -nlt POLYGON -nln wwf_ecoregion

# using pgdump
ogr2ogr -nln countries110m -nlt PROMOTE_TO_MULTI -nlt MULTIPOLYGON -lco precision=NO -overwrite -lco ENCODING=UTF-8 --config PG_USE_COPY YES -f PGDump /vsistdout/ natural_earth_vector.gpkg ne_110m_admin_0_countries | psql -d world -f -

# using shp2pgsql
shp2pgsql -I -s 4326 simplified_land_polygons.shp simplified_land_polygons | psql -d worldmap
```

Import raster

`raster2pgsql -d -s 4326 -I -C -M topo15_43200.tif -F -t 1x1 topo15_43200 | psql -d world`

Import json

```
\set content `cat factbook.json`
CREATE TABLE factbook ( content jsonb );
INSERT INTO factbook values (:'content');
```

Copy db to db

`ogr2ogr -overwrite -lco precision=NO --config PG_USE_COPY YES -f PGDump /vsistdout/ PG:dbname=contours fishbase | psql -d gbif -f -`

Copy table to table

`psql -d world -c "CREATE TABLE ne_10m_admin_0_countries_3857 AS TABLE ne_10m_admin_0_countries;"`

## Exporting

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

Export multiple tables to svg

```
height=800
width=800
psql -d world -c "COPY (WITH b AS (SELECT table_name, string_agg(column_name, ' ' order by ordinal_position) AS columns FROM information_schema.columns GROUP BY table_name) SELECT table_name FROM b WHERE table_name LIKE 'ne_10m%') TO STDOUT;" | while read table; do 
# start svg
echo '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" height="'${height}'" width="'${width}'" viewBox="-20026376 -20048966 40052752 40097932">' > svg/${table}.svg
# get data
psql -d world -c "COPY (WITH b AS (SELECT fid, ST_Transform(geom, 'EPSG:4326', 'EPSG:3857') AS geom, GeometryType(geom) AS type FROM ${table} WHERE ST_Within(geom, ST_MakeEnvelope(-180, -85, 180, 85, 4326))) SELECT fid, ST_X(ST_Centroid(geom)), (-1 * ST_Y(ST_Centroid(geom))), ST_XMin(geom), (-1 * ST_YMax(geom)), (ST_XMax(geom) - ST_XMin(geom)), (ST_YMax(geom) - ST_YMin(geom)), ST_AsSVG(geom, 1, 0), type FROM b) TO STDOUT DELIMITER E'\t'" | while IFS=$'\t' read -a array; do
  case ${array[8]} in
    POINT|MULTIPOINT)
      echo '<circle id="'${array[0]}'" cx="'${array[1]}'" cy="'${array[2]}'" r="1em" vector-effect="non-scaling-stroke" fill="#FFF" fill-opacity="1" stroke="#000" stroke-width="0.1em" stroke-linejoin="round" stroke-linecap="round"/>' >> svg/${table}.svg
      ;;
    LINESTRING|MULTILINESTRING)
      echo '<path id="'${array[0]}'" d="'${array[7]}'" vector-effect="non-scaling-stroke" stroke="#000" stroke-width="0.1em" stroke-linejoin="round" stroke-linecap="round"/>' >> svg/${table}.svg
      ;;
    POLYGON|MULTIPOLYGON)
      echo '<path id="'${array[0]}'" d="'${array[7]}'" vector-effect="non-scaling-stroke" fill="#FFF" fill-opacity="1" stroke="#000" stroke-width="0.1em" stroke-linejoin="round" stroke-linecap="round"/>' >> svg/${table}.svg
      ;;
  esac
done
echo '</svg>' >> svg/${table}.svg
done
```

Export to csv

`psql -d grids -c "COPY (SELECT fid,scalerank,name,adm1name,round(longitude::numeric,2),round(latitude::numeric,2) FROM places) TO STDOUT WITH CSV DELIMITER '|';" > places.csv`

Export to ogr

```
# using ogr
ogr2ogr -overwrite -f "SQLite" -dsco SPATIALITE=YES avh.sqlite PG:dbname=contours avh

# using pgsql2shp
pgsql2shp -f "test" -u steve weather "SELECT metar.station_id,metar.temp_c,ST_MakeLine(metar.geom,metar.translated) FROM metar_20180320_183305 AS metar;
```

## Basic operations

List tables

`COPY (SELECT * FROM pg_catalog.pg_tables) TO STDOUT;`

List columns

```
# search tables that start with ne_10m
COPY (SELECT table_name, string_agg(column_name, ', ' order by ordinal_position) as columns FROM information_schema.columns WHERE table_name LIKE 'ne_10m%' GROUP BY table_name;) TO STDOUT

# search tables that start with ne_10m, has name column
COPY (WITH b AS (SELECT table_name, string_agg(column_name, ' ' order by ordinal_position) AS columns FROM information_schema.columns GROUP BY table_name) SELECT table_name FROM b WHERE table_name LIKE 'ne_10m%' AND (columns LIKE '% name %' OR columns LIKE 'name %' OR columns LIKE '% name')) TO STDOUT;
```

Drop tables with wildcard

```
tables=`psql -d world -P tuples_only=1 -c '\dt' |awk -F" " '/ne_/ {print $3","}'`
psql -d world -c "DROP TABLE ${tables%?};";
```

Add important columns

```
# add new id column
ALTER TABLE wwf_ecoregion ADD COLUMN fid serial primary key;

# choose existing id column
ALTER TABLE places_nogeom ADD PRIMARY KEY (fid);

# create spatial index
CREATE INDEX contour100m_poly_gid ON contour100m_poly USING GIST (geom);

# cluster spatial index
CLUSTER geosnap USING geosnap_gid;
````

Vacuum

```
VACUUM ANALYZE geosnap;
ANALYZE geosnap;
```

Save to external file

`ALTER TABLE allcountries ALTER COLUMN geom SET STORAGE EXTERNAL;`

Cast with mixed column

`UPDATE ${city}_polygons SET levels = (SELECT CAST(other_tags->'building:levels' AS INT) WHERE other_tags->'building:levels' ~ '^[0-9]+$');`

Column to row

`SELECT name, (x).key, (x).value FROM (SELECT name, EACH(hstore(state2020)) AS x FROM state2020) q;`

Get json keys

`SELECT DISTINCT jsonb_object_keys(tags) FROM highway_primary;`

Export json keys

`psql -d world -c "COPY (SELECT '<p>' || row_to_json(t) || '</p>' FROM (SELECT a.nameascii, b.station_id, b.temp, b.wind_sp, b.sky FROM places a, metar b WHERE a.metar_id = b.station_id) t) TO STDOUT;" >> datastream.html;`

Add hstore

`ALTER TABLE ${city}_polygons ALTER COLUMN other_tags TYPE hstore USING other_tags::hstore;`

Convert hstore to text

`psql -d us -c "ALTER TABLE points_${geoid} ALTER COLUMN other_tags TYPE TEXT;`

Get hstore keys

`SELECT DISTINCT skeys(hstore(tags)) FROM planet_osm_polygon;`

Select hstore keys

`UPDATE planet_osm_polygon SET levels = (SELECT tags->'building:levels');`

`SELECT other_tags FROM multipolygons WHERE other_tags LIKE '%construction%';`

Select boolean type

`SELECT b.name, COUNT(b.name) FROM points_us a, acs_2019_5yr_place b WHERE ST_Intersects(a.wkb_geometry, b."Shape") AND ((a.other_tags->'%amenity%')::boolean) GROUP BY b.name ORDER BY COUNT(b.name);`

Random select

`CREATE TABLE contour100m_points1000 AS SELECT * FROM contour100m_points TABLESAMPLE SYSTEM ((1000 * 100) / 5100000.0);`

`SELECT * FROM contour100m_raw WHERE fid IN (SELECT fid FROM contour100m_raw ORDER BY RANDOM() LIMIT 100000);`

Distinct select

`SELECT DISTINCT ON (taxonid) taxonid, vernacularname FROM gbif_vernacular WHERE language IN ('en') ORDER BY taxonid, vernacularname;`

Select

`CREATE TABLE bangkok_toronto_points_neighbourhoods AS SELECT * FROM bangkok_toronto_points WHERE place IN ('neighbourhood');`

Replace string

`UPDATE <table> SET <field> = replace(<field>, 'cat', 'dog');`

Concat strings

`SELECT CONCAT(b.id,';',b.station,';',b.latitude,';',b.longitude,';',b.elevation) FROM ghcn b WHERE a.fid = b.contour100m_id;`

Split part

`UPDATE countryinfo a SET language1 = b.languagename FROM languagecodes b WHERE SPLIT_PART(regexp_replace(a.languages, '-'||a.iso, '', 'g'), ',', 1) = b.iso_639_1 OR SPLIT_PART(a.languages, ',', 1) = b.iso_639_3;`

Split + replace

`SELECT wx, REGEXP_REPLACE(REGEXP_REPLACE(wx,'(\w\w)','\1 ','g'),' +',' ','g') FROM metar;`

Count

```
# count keys (using each)
psql -d us -c "SELECT key, count(key) FROM (SELECT (each(other_tags)).key FROM points_us WHERE name IS NOT NULL) AS stat GROUP BY key;"

# count values (using slice)
SELECT value, count(value) FROM (SELECT svals(slice(other_tags, ARRAY['cuisine'])) value FROM points_us WHERE name IS NOT NULL) AS stat GROUP BY value ORDER BY count DESC;
```

Group and count

`SELECT featurecode,COUNT(featurecode) FROM superior_lines WHERE featureclass IN ('T') GROUP BY featurecode ORDER BY COUNT(featurecode) ASC;`

Rank by variable

`psql -d us -c "SELECT name, dem, RANK() OVER (PARTITION BY admin1 ORDER BY dem DESC) FROM geonames_us;"`

Aggregate

`CREATE TABLE vernacularname_agg AS SELECT taxonid,string_agg(vernacularname,';') FROM vernacularname GROUP BY taxonid;`

## Spatial operations

Print available epsg/srid

`SELECT srid, proj4text FROM spatial_ref_sys;`

Add missing epsg/srid (see spatialreference.org)

```
# eqdc
INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) values ( 953027, 'esri', 53027, '+proj=eqdc +lat_0=0 +lon_0=0 +lat_1=60 +lat_2=60 +x_0=0 +y_0=0 +a=6371000 +b=6371000 +units=m +no_defs ', 'PROJCS["Sphere_Equidistant_Conic",GEOGCS["GCS_Sphere",DATUM["Not_specified_based_on_Authalic_Sphere",SPHEROID["Sphere",6371000,0]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["Equidistant_Conic"],PARAMETER["False_Easting",0],PARAMETER["False_Northing",0],PARAMETER["Central_Meridian",0],PARAMETER["Standard_Parallel_1",60],PARAMETER["Standard_Parallel_2",60],PARAMETER["Latitude_Of_Origin",0],UNIT["Meter",1],AUTHORITY["EPSG","53027"]]');

# tpeqd
INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) values ( 954031, 'esri', 54031, '+proj=tpeqd +lat_1=0 +lon_1=0 +lat_2=60 +lon_2=60 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs ', 'PROJCS["World_Two_Point_Equidistant",GEOGCS["GCS_WGS_1984",DATUM["WGS_1984",SPHEROID["WGS_1984",6378137,298.257223563]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["Two_Point_Equidistant"],PARAMETER["False_Easting",0],PARAMETER["False_Northing",0],PARAMETER["Latitude_Of_1st_Point",0],PARAMETER["Latitude_Of_2nd_Point",60],PARAMETER["Longitude_Of_1st_Point",0],PARAMETER["Longitude_Of_2nd_Point",60],UNIT["Meter",1],AUTHORITY["EPSG","54031"]]');

# vandg
INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) values ( 53029, 'ESRI', 53029, '+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m +no_defs ', 'PROJCS["Sphere_Van_der_Grinten_I",GEOGCS["GCS_Sphere",DATUM["Not_specified_based_on_Authalic_Sphere",SPHEROID["Sphere",6371000,0]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["VanDerGrinten"],PARAMETER["False_Easting",0],PARAMETER["False_Northing",0],PARAMETER["Central_Meridian",0],UNIT["Meter",1],AUTHORITY["EPSG","53029"]]');
```

Create geometry column

`ALTER TABLE contour10m_dissolve ADD COLUMN geom TYPE GEOMETRY(MULTILINESTRING,4326);`

Change geometry type

`ALTER TABLE milan_point ALTER COLUMN way type geometry(Polygon, 4326);`

`ALTER TABLE limw_points ALTER TABLE contour100m_id TYPE INT USING contour100m_id::integer;`

Extract geometry collection

`UPDATE places_voronoi set geom = ST_CollectionExtract(ST_VoronoiPolygons(b.geom),3) FROM places b;`

Reproject

```
# reproject
CREATE TABLE ne_10m_admin_0_countries_lakes_3857 AS SELECT * FROM ne_10m_admin_0_countries_lakes;
ALTER TABLE ne_10m_admin_0_countries_lakes_3857 ALTER COLUMN geom type geometry;
UPDATE ne_10m_admin_0_countries_lakes_3857 SET geom = ST_Transform(ST_SetSRID(geom,4326),3857);

# with contain
CREATE TABLE ne_10m_admin_0_countries_lakes_3857 AS SELECT * FROM ne_10m_admin_0_countries_lakes WHERE ST_Contains(ST_MakeEnvelope(-180, -90, 180, 90, 4326),geom);
ALTER TABLE ne_10m_admin_0_countries_lakes_3857 ALTER COLUMN geom type geometry;
UPDATE ne_10m_admin_0_countries_lakes_3857 SET geom = ST_Transform(ST_SetSRID(geom,4326),3857);

# with intersection
CREATE TABLE ne_10m_admin_0_countries_lakes_3857 AS SELECT * FROM ne_10m_admin_0_countries_lakes;
ALTER TABLE ne_10m_admin_0_countries_lakes_3857 ALTER COLUMN geom type geometry;
UPDATE ne_10m_admin_0_countries_lakes_3857 SET geom = ST_Intersection(ST_MakeEnvelope(-20037508.34, -20048966.1,
20037508.34, 20048966.1, 3857), ST_Transform(ST_SetSRID(geom,4326),3857));
```

Update SRID

`SELECT UpdateGeometrySRID('hydroriver_simple_3857', 'shape', 3857);`

Translate

```
ALTER TABLE metar_20180320_183305 ADD COLUMN translated geometry(Point,4326);
UPDATE metar_20180320_183305 SET translated=ST_SetSrid(ST_Translate(geom,0.1,0),4326);
```

Make valid

`UPDATE polygon_voronoi SET way = ST_MakeValid(way) WHERE NOT ST_IsValid(way);`

Sample raster at points

`UPDATE places a SET dem = ST_Value(r.rast, 1, a.geom) FROM topo15_43200 r WHERE ST_Intersects(r.rast,a.geom);`

Get angle (degrees)

`SELECT ST_Azimuth(ST_Startpoint(way), ST_Endpoint(way))/(2*pi())*360 FROM planet_osm_line;`

Get road angle (degrees)

`UPDATE city_points a SET road_angle = ST_Azimuth(a.geom,ST_ClosestPoint(a.geom,b.geom))/(2*pi())*360 FROM city_roads b;`

Label angle epsg:4326 -> epsg:53209 

```
ALTER TABLE countries110m ADD COLUMN angle53029 int;
UPDATE countries110m SET angle53029 = ST_Azimuth(ST_Transform(ST_Centroid(geom),'EPSG:4326','+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m no_defs'),ST_Transform(ST_Translate(ST_Centroid(geom),0.1,0),'EPSG:4326','+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m no_defs'))/(2*pi())*360;
UPDATE marine110m SET angle53029 = ST_Azimuth(ST_Transform(ST_Centroid(ST_Buffer(geom,0)),'EPSG:4326','+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m no_defs'),ST_Transform(ST_Intersection(ST_MakeEnvelope(-175, -85, 175, 85, 4326),ST_Translate(ST_Centroid(ST_Buffer(geom,0)),0.1,0)),'EPSG:4326','+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m no_defs'))/(2*pi())*360;
```

Snap polygon to grid

```
CREATE TABLE countries_snap AS SELECT * FROM countries10m;
ALTER TABLE countries_snap ALTER COLUMN geom type geometry;
UPDATE countries_snap a SET geom = ST_Buffer(ST_SnapToGrid(b.geom,1),0) FROM countries10m b WHERE a.fid = b.fid;
```

Snap line to grid

`UPDATE places_snap02 SET geom = ST_SnapToGrid(ST_Segmentize(geom,0.2),0.2);`

Snap to layer

`CREATE TABLE places_snap02 AS SELECT a.fid, a.name, a.adm0name, ST_Snap(a.geom, b.geom, 0.2) geom FROM places a, points02 b;`

Simplify

`CREATE TABLE subunits_simple01 AS SELECT name, ST_SimplifyPreserveTopology(geom, 0.1) AS geom FROM subunits;`

Smooth label geom

`UPDATE countries_labels_3857 a SET geom = ST_Buffer(ST_Buffer(b.geom,10000),-10000) FROM countries_3857 b WHERE a.fid = b.fid;`

Dump points

`CREATE TABLE contour100m_points AS SELECT elev, (ST_DumpPoints(geom)).geom::geometry(POINTZ,4326) AS geom FROM contour100m GROUP BY elev, geom;`

Interpolate points

`CREATE TABLE contour10m_points1 AS WITH lines AS (SELECT elev, (ST_Dump(ST_Segmentize(geom,1))).geom::geometry(LINESTRING,4326) AS geom FROM contour10m_dissolve GROUP BY elev, geom) SELECT elev, ST_LineInterpolatePoint(geom,0.5)::GEOMETRY(POINT,4326) geom FROM lines;`

Get centroid

`SELECT name, ST_Centroid(ST_Multi(ST_Union(l.way))) AS singlegeom FROM planet_osm_line AS l WHERE name IS NOT NULL AND highway IN ('primary','secondary') GROUP BY name;`

`CREATE TABLE contour20m_points AS SELECT elev, (ST_Centroid(ST_SimplifyPreserveTopology(geom,0.1)))::geometry(POINT,4326) AS geom FROM contour20m_43200 GROUP BY elev, geom;`

Get geometric median

`CREATE TABLE superior_medians AS SELECT featurecode, COUNT(featurecode),  ST_GeometricMedian(ST_Collect(geom)) AS geom FROM superior GROUP BY featurecode;`

Cluster

`UPDATE nmnh_italy SET cid = clusterid FROM (SELECT fid, ST_ClusterDBSCAN(geom,1,1) OVER () AS clusterid FROM nmnh_italy) cluster WHERE cluster.fid = nmnh_italy.fid;`

`UPDATE allcountries a SET clusterid = b.cid FROM (SELECT ST_ClusterDBSCAN(geom, eps:=2, minpoints:=2) OVER (PARTITION BY fcode_en_name) AS cid, fid FROM allcountries) AS b WHERE a.fid = b.fid;`

Medial axis

`SELECT ST_ApproximateMedialAxis(geom) FROM countries;`

Buffers

```
# simple
UPDATE places_voronoi_buffer1 SET geom = st_buffer(geom, 1, 'endcap=square join=miter');

# multibuffers
CREATE TABLE places_buffers AS SELECT a.name, '0' AS buffer, b.geom FROM places a, grid02 b WHERE ST_Intersects(a.geom, b.geom) UNION SELECT a.name, '01' AS buffer, b.geom FROM places a, grid02 b WHERE ST_Intersects(ST_Buffer(a.geom,0.1), b.geom);

# variable width buffers
CREATE TABLE riveratlas_v10_simple1_buffer_1000 AS WITH buffer AS (SELECT ST_Buffer(shape,width_bucket(upland_skm,0,10000,10)*0.005) geom FROM riveratlas_v10_simple1 WHERE upland_skm >= 1000) SELECT (ST_Dump(ST_Union(geom))).geom::GEOMETRY(POLYGON,4326) geom FROM buffer;
```

Dissolve/union

`CREATE TABLE limw_dissolve AS SELECT xx_name, ST_CollectionExtract(ST_Union(geom),3) geom FROM limw GROUP BY xx_name;`

`CREATE TABLE contour100m_dissolve AS SELECT (ST_Dump(ST_Union(geom))).geom::GEOMETRY(LINESTRING,4326) geom from contour100m;`

`UPDATE grid04_countries a SET geom = (SELECT ST_Multi(ST_Union(b.geom))::GEOMETRY(MULTIPOLYGON, 4326) FROM grid04 b WHERE ST_Intersects(a.geom, b.geom));`

`CREATE TABLE wwf_ecoregion AS SELECT eco_name, realm_name, biome_name, ST_Union(geom) AS geom FROM wwf_ecoregion_test GROUP BY eco_name, realm_name, biome_name;`

Difference

```
# subtract river buffers from basin
CREATE TABLE basinatlas_v10_lev01_rivers AS SELECT * FROM basinatlas_v10_lev01;
UPDATE basinatlas_v10_lev01_rivers a SET shape = ST_Difference(a.shape,b.geom) FROM riveratlas_v10_simple1_buffer b;
```

Aggregate by geom

```
# create table
CREATE TABLE places_label_italy AS SELECT STRING_AGG(name, ',' ORDER BY ST_X(geom)) AS names, ST_SetSRID(ST_MakePoint(ST_XMin(ST_Multi(ST_Union(geom))), ST_Y(geom)), 4326)::geometry(POINT, 4326) AS geom FROM places_snap02 WHERE adm0name IN ('Italy') GROUP BY ST_Y(geom);

# aggregate names
UPDATE grid02 a SET places = (SELECT string_agg(b.name, ',' ORDER BY b.scalerank) FROM places b WHERE ST_Intersects(a.geom, b.geom));
```

Find Nearest neighbor

```
UPDATE gebco_contour1 a SET geom = (SELECT b.geom FROM contour10m_segment1 b WHERE ST_DWithin(a.geom,b.geom,1) ORDER BY a.geom <-> b.geom LIMIT 1);

# within extent
SELECT a.geonameid,a.name,a.asciiname,a.altnames,a.lat,a.lon,a.featureclass,a.featurecode,a.countrycode,a.admin1,a.admin2,a.admin3,a.admin4,a.population,a.elevation,a.dem,a.timezone,a.featurecode_name,a.featurecode_notes, (SELECT b.geom FROM contour10m_segments AS b ORDER BY b.geom <-> ST_Union(ST_Intersect(a.geom)) LIMIT 1) FROM allcountries AS a WHERE a.geom && ST_MakeEnvelope(-94,43,-83,52);

SELECT a.gbifid, a.kingdom, a.phylum, a.class, a.order, a.family, a.genus, a.species, a.scientificname, a.decimallatitude, a.decimallongitude, a.elevation, a.depth, (SELECT b.geom FROM contour10m_segments AS b ORDER BY b.geom <-> a.geom LIMIT 1) FROM nmnh AS a WHERE a.geom && ST_MakeEnvelope(-94,43,-83,52);

# grouped by median
SELECT a.species, (SELECT b.geom FROM contour10m_segments AS b ORDER BY b.geom <-> ST_GeometricMedian(ST_Collect(a.geom)) LIMIT 1) FROM insdc AS a WHERE a.geom && ST_MakeEnvelope(-94,43,-83,52) GROUP BY a.species;

# grouped by n
SELECT a.featurecode_name, a.featureclass, (SELECT b.geom FROM contour10m_segments AS b ORDER BY b.geom <-> ST_GeometryN(ST_Collect(a.geom),1) LIMIT 1) FROM allcountries AS a WHERE a.geom && ST_MakeEnvelope(-94,43,-83,52) AND a.featureclass IN ('T','H','U','V') GROUP BY a.featurecode_name, a.featureclass;

# single point
SELECT * FROM tor_female WHERE CTUID = (SELECT CTUID FROM toronto_points_ct ORDER BY geom <-> ST_SetSRID(ST_MakePoint(-79.40,43.67),4326) LIMIT 1);

# nearest METARS station
SELECT m.station_id FROM ${mytable} AS m ORDER BY m.geom <-> p.geom LIMIT 1;

# with cte
CREATE TABLE labels_italy AS WITH points AS (SELECT (ST_DumpPoints(b.geom)).geom::GEOMETRY(point, 4326) as geom FROM countries b WHERE name IN ('Italy')) SELECT a.name, (SELECT b.geom FROM points b ORDER BY b.geom <-> a.geom LIMIT 1) FROM places a WHERE adm0name IN ('Italy');

# cross join
CREATE TABLE contour10m_classt AS SELECT b.fcode_en_name, a.geom FROM contour10m_segment1 a CROSS JOIN LATERAL (SELECT fcode_en_name, geom FROM allcountries WHERE featureclass = 'T' AND a.elev >= 0 AND ST_DWithin(a.geom,geom,0.1) ORDER BY a.geom <-> geom LIMIT 1) b;
```

Make contours

```
CREATE TABLE wwf_ecoregion_split4 AS SELECT * FROM wwf_ecoregion;
ALTER TABLE wwf_ecoregion_split4 ALTER COLUMN geom TYPE geometry;
UPDATE wwf_ecoregion_split4 a SET geom = (SELECT b.geom FROM contour100m_split4 b WHERE ST_DWithin(a.geom, b.geom, 1) ORDER BY a.geom <-> b.geom LIMIT 1);
ALTER TABLE wwf_ecoregion_split4 ALTER COLUMN geom TYPE geometry(MULTILINESTRING,4326);
```

Intersection (clipping)

`CREATE TABLE contour10m_superior AS SELECT ST_Intersection(a.geom, b.geom) AS geom FROM contour10m AS a, envelope_superior AS b WHERE ST_Intersects(a.geom, b.geom);`

`CREATE TABLE ne_10m_roads_countries AS SELECT a.fid AS fid_road, b.fid AS fid_country, ST_Intersection(a.geom, b.geom) AS geom FROM ne_10m_roads a, ne_10m_admin_0_countries b WHERE ST_Intersects(a.geom, b.geom);`

Polygon clipping

`CREATE TABLE subregions_3857 AS SELECT subregion, ST_Intersection(geom, ST_MakeEnvelope(-179, -89, 179, 89, 4326)) geom FROM subregions;`

Intersects

`CREATE TABLE test2 AS SELECT a.id, b.osm_id, a.geom FROM grid100 AS a, planet_osm_polygon AS b WHERE ST_Intersects(a.geom, b.way);`

`UPDATE grid100 a SET line_id = b.osm_id FROM planet_osm_line b WHERE ST_Intersects(a.geom,b.way) AND b.highway IN ('motorway','primary','secondary','tertiary','residential');`

`SELECT count(*), c.name FROM countries c JOIN places p ON ST_Intersects(c.geom, p.geom) GROUP BY c.name;`

Make extent/envelope

`SELECT ST_Extent(way) FROM planet_osm_polygon;`

`SELECT ST_ExteriorRing(ST_Envelope(ST_Collect(GEOMETRY))) FROM contour10;`

`SELECT ST_Envelope(ST_Collect(GEOMETRY)) FROM contour10;`

Make grid

```
# world extent
CREATE TABLE grid1 AS SELECT (ST_PixelAsPolygons(ST_AddBand(ST_MakeEmptyRaster(360,180,0,0,1,1,0,0,4326), '8BSI'::text, 1, 0), 1, false)).geom::geometry(Polygon,4326) AS geom;

# select extent
CREATE TABLE grid0001 AS SELECT (ST_PixelAsPolygons(ST_AddBand(ST_MakeEmptyRaster((SELECT ((ST_XMax(ST_Extent(way))-ST_XMin(ST_Extent(way)))/0.001)::numeric::integer FROM planet_osm_polygon), (SELECT ((ST_YMax(ST_Extent(way))-ST_YMin(ST_Extent(way)))/0.001)::numeric::integer FROM planet_osm_polygon), (SELECT ST_XMin(ST_Extent(way)) FROM planet_osm_polygon), (SELECT ST_YMin(ST_Extent(way)) FROM planet_osm_polygon), 0.001, 0.001, 0, 0, 4326), '8BSI'::text, 1, 0), 1, false)).geom::geometry(Polygon,4326) AS geom;
```

Make triangles

```
# voronoi
CREATE TABLE hood_voronoi AS SELECT (ST_DUMP(ST_VoronoiPolygons(ST_Collect(p.way)))).geom FROM planet_osm_point AS p WHERE place IN ('neighbourhood');

CREATE TABLE points_04013_voronoi_amenity AS WITH b AS (SELECT (ST_Dump(ST_VoronoiPolygons(ST_Collect(wkb_geometry)))).geom::GEOMETRY(POLYGON,4269) wkb_geometry FROM points_04013 WHERE other_tags LIKE '%amenity%') SELECT ST_Intersection(a."SHAPE", b.wkb_geometry) wkb_geometry FROM county a, b WHERE ST_Intersects(a."SHAPE", b.wkb_geometry) AND a.geoid = '04013';

# delaunay
CREATE TABLE places_delaunay AS SELECT (ST_Dump(ST_DelaunayTriangles(ST_Union(geom),0.001,1))).geom::geometry(LINESTRING,4326) AS geom FROM places;
```

Polygonize

```
# contours
CREATE TABLE contour100m_poly AS SELECT fid, elev, (ST_Dump(ST_MakePolygon(geom))).geom::geometry(POLYGON,4326) AS geom FROM contour100m WHERE ST_IsClosed(geom);

# lines to polygons (using polygonize)
CREATE TABLE seoul_highway_polygons AS WITH b AS (SELECT ST_Multi(ST_Node(ST_Collect(wkb_geometry))) wkb_geometry FROM seoul_lines WHERE highway IN ('motorway','trunk','primary','secondary','tertiary','residential')) SELECT (ST_Dump(ST_Polygonize(wkb_geometry))).geom::GEOMETRY(POLYGON,3857) wkb_geometry FROM b;

# lines to polygons (using extent)
CREATE TABLE ${place}_extent_highways AS SELECT (ST_Dump(ST_CollectionExtract(ST_Split(a.wkb_geometry,b.wkb_geometry),3))).geom::GEOMETRY(POLYGON,3857) wkb_geometry FROM (SELECT ST_Extent(wkb_geometry)::GEOMETRY(POLYGON,3857) wkb_geometry FROM ${place}_lines) a, (SELECT (ST_Union(wkb_geometry))::GEOMETRY(MULTILINESTRING,3857) wkb_geometry FROM ${place}_lines WHERE highway IN ('motorway','trunk','primary','secondary','tertiary','residential')) b;
```

Contour to delaunay to sample raster

```
DROP TABLE topo15_43200_100m_simple10_points; drop table topo15_43200_100m_simple10_delaunay;
CREATE TABLE topo15_43200_100m_simple10_points as select (st_dumppoints(st_simplify(geom,10))).geom::geometry(POINT,4326) as geom FROM topo15_43200_100m;
CREATE TABLE topo15_43200_100m_simple10_delaunay AS SELECT (ST_Dump(ST_DelaunayTriangles(ST_Union(geom)))).geom::geometry(POLYGON,4326) AS geom FROM topo15_43200_100m_simple10_points;
ALTER TABLE topo15_43200_100m_simple10_delaunay ADD COLUMN dem_mean int; UPDATE topo15_43200_100m_simple10_delaunay a SET dem_mean = (ST_SummaryStats(rast)).mean FROM topo15_4320 b WHERE ST_Intersects(b.rast, a.geom);
ALTER TABLE topo15_43200_100m_simple10_delaunay ADD COLUMN aspect_mean int; UPDATE topo15_43200_100m_simple10_delaunay a SET aspect_mean = (ST_SummaryStats(rast)).mean FROM topo15_4320_aspect b WHERE ST_Intersects(b.rast, a.geom);
```

Basin to voronoi to sample raster

```
CREATE TABLE basinatlas_v10_lev04_points AS SELECT objectid, (st_dumppoints(st_simplify("Shape",1))).geom::geometry(POINT,4326) as "Shape", aspect_mean FROM basinatlas_v10_lev04;
CREATE TABLE basinatlas_v10_lev04_voronoi AS SELECT (ST_DUMP(ST_VoronoiPolygons(ST_Collect("Shape")))).geom as "Shape" FROM basinatlas_v10_lev04_points;
ALTER TABLE basinatlas_v10_lev04_voronoi ADD COLUMN aspect_mean int; UPDATE basinatlas_v10_lev04_voronoi a SET aspect_mean = (ST_SummaryStats(rast)).mean FROM topo15_4320_aspect b WHERE ST_Intersects(b.rast, a."Shape");
ALTER TABLE basinatlas_v10_lev04_voronoi ADD COLUMN dem_mean int; UPDATE basinatlas_v10_lev04_voronoi a SET dem_mean = (ST_SummaryStats(rast)).mean FROM topo15_4320 b WHERE ST_Intersects(b.rast, a."Shape");
```

Line to geometry

`CREATE TABLE labels_italy AS WITH mybuffer AS (SELECT ST_ExteriorRing(ST_Buffer(ST_Centroid(ST_Collect(geom)), 5, 24)) AS geom FROM countries WHERE name IN ('Italy')), myline AS (SELECT a.name, a.scalerank, ST_MakeLine(a.geom, ST_ClosestPoint(b.geom, a.geom))::GEOMETRY(LINESTRING, 4326) AS geom FROM places_snap02 a, mybuffer b WHERE a.adm0name IN ('Italy')) SELECT name, scalerank,  ST_MakeLine(ST_StartPoint(geom), (ST_Project(ST_StartPoint(geom), ST_Distance(ST_StartPoint(geom)::GEOGRAPHY, ST_EndPoint(geom)::GEOGRAPHY)*2, ST_Azimuth(ST_StartPoint(geom), ST_EndPoint(geom))))::GEOMETRY(POINT, 4326))::GEOMETRY(LINESTRING, 4326) FROM myline;`

Line to circle buffer

`CREATE TABLE places_labels AS WITH mybuffer AS (SELECT adm0name, ST_ExteriorRing(ST_Buffer(ST_Centroid(ST_Collect(geom)), 10, 24))::GEOMETRY(LINESTRING,4326) AS geom FROM places GROUP BY adm0name) SELECT a.fid, a.name, a.scalerank, a.adm0name, ST_MakeLine(a.geom, ST_ClosestPoint(b.geom, a.geom))::GEOMETRY(LINESTRING, 4326) AS geom FROM places a, mybuffer b WHERE a.adm0name = b.adm0name;`

Fill proj definition with region centroids

```
psql -d world -c "copy (select subregion, round(st_x(geom)), round(st_y(geom)) from (select subregion, st_centroid(st_union(geom)) geom from ne_10m_admin_0_countries_lakes group by subregion) b) to stdout DELIMITER E'\t';" | while IFS=$'\t' read -a array; do echo "WHEN attribute(@atlas_feature,'subregion') IN ('${array[0]}') THEN 'PROJ:+proj=ortho +lat_0=${array[2]} +lon_0=${array[1]} +ellps=sphere'"; done
```

Text as polygons (using width_bucket to scale letters)

`DROP TABLE IF EXISTS ne_10m_admin_0_map_subunits_letters; CREATE TABLE ne_10m_admin_0_map_subunits_letters AS SELECT name, type, ST_SetSRID(ST_Translate(ST_Scale(ST_Letters(upper(name_en)), width_bucket(area,0,300,5)*0.01, width_bucket(area,0,300,5)*0.01), ST_XMIN(geom) + ((ST_X(ST_Centroid(geom))-ST_XMIN(geom))/2), ST_Y(ST_Centroid(geom))), 4326) geom FROM ne_10m_admin_0_map_subunits;`

## Dataset examples

### OpenStreetMap

Import points, lines, multilines & polygons from shell

```
# for hstore: -lco COLUMN_TYPES=other_tags=hstore
osmfile=java-latest.osm.pbf
ogr2ogr -overwrite -f PostgreSQL -t_srs "EPSG:3857" -nln ${osmfile%.osm.pbf}_points PG:dbname=osm ${osmfile} points
ogr2ogr -overwrite -f PostgreSQL -t_srs "EPSG:3857" -nln ${osmfile%.osm.pbf}_lines PG:dbname=osm ${osmfile} lines
ogr2ogr -overwrite -f PostgreSQL -t_srs "EPSG:3857" -nlt promote_to_multi -nln ${osmfile%.osm.pbf}_multilines PG:dbname=osm ${osmfile} multilinestrings
ogr2ogr -overwrite -f PostgreSQL -t_srs "EPSG:3857" -nlt promote_to_multi -nln ${osmfile%.osm.pbf}_polygons PG:dbname=osm ${osmfile} multipolygons
```

Use ST_IsValid for broken polygons

`SELECT ST_Buffer(wkb_geometry,0) wkb_geometry FROM bangkok_polygons WHERE building IS NOT NULL AND ST_IsValid(wkb_geometry)`

Working with other_tags

```
# list other_tags
SELECT DISTINCT other_tags FROM bangkok_polygons WHERE other_tags IS NOT NULL ORDER BY other_tags;
```

Highways

```
# dissolve highways by name
CREATE TABLE bangkok_highway_dissolve AS SELECT name, highway, ST_Union(wkb_geometry) wkb_geometry FROM bangkok_lines GROUP BY name, highway; 

# dissolve highways by neighborhood
SELECT ST_Union(ST_Intersection(a.wkb_geometry,b.wkb_geometry)) wkb_geometry FROM bangkok_lines a, bangkok_polygons b WHERE b.admin_level IN ('8') GROUP BY b.wkb_geometry;

# buffer highways by type
CREATE TABLE bangkok_highway_buffer5 AS SELECT highway, (ST_Dump(ST_Union(ST_Buffer(wkb_geometry,5)))).geom::GEOMETRY(POLYGON,3857) wkb_geometry FROM bangkok_lines GROUP BY highway;
```

Public transportation

```
# select all public transport stations
SELECT name, other_tags FROM bangkok_points WHERE other_tags LIKE '%"public_transport"=>"station"%';

# create table of subways stations
CREATE TABLE bangkok_subway_stations AS SELECT * FROM bangkok_points WHERE other_tags LIKE '%station"=>"subway"%';
```

Batch processing from shell

```
place=amsterdam
# highway to polygon
psql -d osm -c "DROP TABLE IF EXISTS ${place}_highway_polygons; CREATE TABLE ${place}_highway_polygons AS SELECT (ST_Dump(ST_CollectionExtract(ST_Split(a.wkb_geometry,b.wkb_geometry),3))).geom::GEOMETRY(POLYGON,3857) wkb_geometry FROM (SELECT ST_Extent(wkb_geometry)::GEOMETRY(POLYGON,3857) wkb_geometry FROM ${place}_lines) a, (SELECT (ST_Union(wkb_geometry))::GEOMETRY(MULTILINESTRING,3857) wkb_geometry FROM ${place}_lines WHERE highway IN ('motorway','trunk','primary','secondary','tertiary','residential')) b;"
# add indexes
psql -d osm -c "ALTER TABLE ${place}_highway_polygons ADD COLUMN fid serial PRIMARY KEY;"
psql -d osm -c "CREATE INDEX ${place}_highway_polygons_gid ON ${place}_highway_polygons USING GIST (wkb_geometry);"
# add landuse
psql -d osm -c "ALTER TABLE ${place}_highway_polygons ADD COLUMN landuse text; UPDATE ${place}_highway_polygons SET landuse = NULL; UPDATE ${place}_highway_polygons a SET landuse = b.landuse FROM ${place}_polygons b WHERE ST_Intersects(a.wkb_geometry,ST_Buffer(b.wkb_geometry,0)) AND b.landuse IS NOT NULL AND ST_IsValid(b.wkb_geometry);"
# add natural
psql -d osm -c "ALTER TABLE ${place}_highway_polygons ADD COLUMN \"natural\" text; UPDATE ${place}_highway_polygons SET \"natural\" = NULL; UPDATE ${place}_highway_polygons a SET \"natural\" = b.natural FROM ${place}_polygons b WHERE ST_Intersects(a.wkb_geometry,ST_Buffer(b.wkb_geometry,0)) AND b.natural IS NOT NULL AND ST_IsValid(b.wkb_geometry);"

# count amenties by neighborhood
psql -d osm -c "ALTER TABLE ${place}_polygons ADD COLUMN amenity_count int;"
psql -d osm -c "WITH stats AS (SELECT a.osm_id, count(b.other_tags LIKE '%amenity%') count FROM ${place}_polygons a, ${place}_points b WHERE a.admin_level IS NOT NULL AND b.other_tags LIKE '%amenity%' AND ST_Intersects(a.wkb_geometry, b.wkb_geometry) GROUP BY a.osm_id) UPDATE ${place}_polygons a SET amenity_count = stats.count FROM stats WHERE a.osm_id = stats.osm_id;"
```

### Hydroatlas

Import hydroatlas

```
# import
ogr2ogr -f PostgreSQL PG:dbname=world RiverATLAS_v10.gdb RiverATLAS_v10
ogr2ogr -f PostgreSQL PG:dbname=world -nlt PROMOTE_TO_MULTI BasinATLAS_v10.gdb
```

Buffer hack for processing basins

```
echo $(psql -qAtX -d world -c '\d basinatlas_v10_lev01' | grep -v "shape" | sed -e 's/|.*//g' | paste -sd',')
for a in {01..12}; do
  psql -d world -c "CREATE TABLE basinatlas_v10_lev${a}_buffer0 AS SELECT objectid,hybas_id,next_down,next_sink,main_bas,dist_sink,dist_main,sub_area,up_area,pfaf_id,endo,coast,order_,sort,dis_m3_pyr,dis_m3_pmn,dis_m3_pmx,run_mm_syr,inu_pc_smn,inu_pc_umn,inu_pc_smx,inu_pc_umx,inu_pc_slt,inu_pc_ult,lka_pc_sse,lka_pc_use,lkv_mc_usu,rev_mc_usu,dor_pc_pva,ria_ha_ssu,ria_ha_usu,riv_tc_ssu,riv_tc_usu,gwt_cm_sav,ele_mt_sav,ele_mt_uav,ele_mt_smn,ele_mt_smx,slp_dg_sav,slp_dg_uav,sgr_dk_sav,clz_cl_smj,cls_cl_smj,tmp_dc_syr,tmp_dc_uyr,tmp_dc_smn,tmp_dc_smx,tmp_dc_s01,tmp_dc_s02,tmp_dc_s03,tmp_dc_s04,tmp_dc_s05,tmp_dc_s06,tmp_dc_s07,tmp_dc_s08,tmp_dc_s09,tmp_dc_s10,tmp_dc_s11,tmp_dc_s12,pre_mm_syr,pre_mm_uyr,pre_mm_s01,pre_mm_s02,pre_mm_s03,pre_mm_s04,pre_mm_s05,pre_mm_s06,pre_mm_s07,pre_mm_s08,pre_mm_s09,pre_mm_s10,pre_mm_s11,pre_mm_s12,pet_mm_syr,pet_mm_uyr,pet_mm_s01,pet_mm_s02,pet_mm_s03,pet_mm_s04,pet_mm_s05,pet_mm_s06,pet_mm_s07,pet_mm_s08,pet_mm_s09,pet_mm_s10,pet_mm_s11,pet_mm_s12,aet_mm_syr,aet_mm_uyr,aet_mm_s01,aet_mm_s02,aet_mm_s03,aet_mm_s04,aet_mm_s05,aet_mm_s06,aet_mm_s07,aet_mm_s08,aet_mm_s09,aet_mm_s10,aet_mm_s11,aet_mm_s12,ari_ix_sav,ari_ix_uav,cmi_ix_syr,cmi_ix_uyr,cmi_ix_s01,cmi_ix_s02,cmi_ix_s03,cmi_ix_s04,cmi_ix_s05,cmi_ix_s06,cmi_ix_s07,cmi_ix_s08,cmi_ix_s09,cmi_ix_s10,cmi_ix_s11,cmi_ix_s12,snw_pc_syr,snw_pc_uyr,snw_pc_smx,snw_pc_s01,snw_pc_s02,snw_pc_s03,snw_pc_s04,snw_pc_s05,snw_pc_s06,snw_pc_s07,snw_pc_s08,snw_pc_s09,snw_pc_s10,snw_pc_s11,snw_pc_s12,glc_cl_smj,glc_pc_s01,glc_pc_s02,glc_pc_s03,glc_pc_s04,glc_pc_s05,glc_pc_s06,glc_pc_s07,glc_pc_s08,glc_pc_s09,glc_pc_s10,glc_pc_s11,glc_pc_s12,glc_pc_s13,glc_pc_s14,glc_pc_s15,glc_pc_s16,glc_pc_s17,glc_pc_s18,glc_pc_s19,glc_pc_s20,glc_pc_s21,glc_pc_s22,glc_pc_u01,glc_pc_u02,glc_pc_u03,glc_pc_u04,glc_pc_u05,glc_pc_u06,glc_pc_u07,glc_pc_u08,glc_pc_u09,glc_pc_u10,glc_pc_u11,glc_pc_u12,glc_pc_u13,glc_pc_u14,glc_pc_u15,glc_pc_u16,glc_pc_u17,glc_pc_u18,glc_pc_u19,glc_pc_u20,glc_pc_u21,glc_pc_u22,pnv_cl_smj,pnv_pc_s01,pnv_pc_s02,pnv_pc_s03,pnv_pc_s04,pnv_pc_s05,pnv_pc_s06,pnv_pc_s07,pnv_pc_s08,pnv_pc_s09,pnv_pc_s10,pnv_pc_s11,pnv_pc_s12,pnv_pc_s13,pnv_pc_s14,pnv_pc_s15,pnv_pc_u01,pnv_pc_u02,pnv_pc_u03,pnv_pc_u04,pnv_pc_u05,pnv_pc_u06,pnv_pc_u07,pnv_pc_u08,pnv_pc_u09,pnv_pc_u10,pnv_pc_u11,pnv_pc_u12,pnv_pc_u13,pnv_pc_u14,pnv_pc_u15,wet_cl_smj,wet_pc_sg1,wet_pc_ug1,wet_pc_sg2,wet_pc_ug2,wet_pc_s01,wet_pc_s02,wet_pc_s03,wet_pc_s04,wet_pc_s05,wet_pc_s06,wet_pc_s07,wet_pc_s08,wet_pc_s09,wet_pc_u01,wet_pc_u02,wet_pc_u03,wet_pc_u04,wet_pc_u05,wet_pc_u06,wet_pc_u07,wet_pc_u08,wet_pc_u09,for_pc_sse,for_pc_use,crp_pc_sse,crp_pc_use,pst_pc_sse,pst_pc_use,ire_pc_sse,ire_pc_use,gla_pc_sse,gla_pc_use,prm_pc_sse,prm_pc_use,pac_pc_sse,pac_pc_use,tbi_cl_smj,tec_cl_smj,fmh_cl_smj,fec_cl_smj,cly_pc_sav,cly_pc_uav,slt_pc_sav,slt_pc_uav,snd_pc_sav,snd_pc_uav,soc_th_sav,soc_th_uav,swc_pc_syr,swc_pc_uyr,swc_pc_s01,swc_pc_s02,swc_pc_s03,swc_pc_s04,swc_pc_s05,swc_pc_s06,swc_pc_s07,swc_pc_s08,swc_pc_s09,swc_pc_s10,swc_pc_s11,swc_pc_s12,lit_cl_smj,kar_pc_sse,kar_pc_use,ero_kh_sav,ero_kh_uav,pop_ct_ssu,pop_ct_usu,ppd_pk_sav,ppd_pk_uav,urb_pc_sse,urb_pc_use,nli_ix_sav,nli_ix_uav,rdd_mk_sav,rdd_mk_uav,hft_ix_s93,hft_ix_u93,hft_ix_s09,hft_ix_u09,gad_id_smj,gdp_ud_sav,gdp_ud_ssu,gdp_ud_usu,hdi_ix_sav,shape_length,shape_area,dem_mean,aspect_mean, ST_Buffer(shape,0) FROM basinatlas_v10_lev${a};"
done

# buffer rivers
CREATE TABLE riveratlas_v10_simple1_buffer_upland_skm_500 AS SELECT ST_Buffer(shape,width_bucket(upland_skm,0,1000,10)*0.005) geom FROM riveratlas_v10_simple1 WHERE upland_skm >= 500;
CREATE TABLE riveratlas_v10_simple1_buffer_500_dissolve AS SELECT (ST_Dump(ST_Union(geom))).geom::GEOMETRY(POLYGON,4326) geom FROM riveratlas_v10_simple1_buffer_upland_skm_500;
```

Sample raster

```
# import rasters
raster2pgsql -d -s 4326 -I -C -M -F -t 1x1 topo15_4320.tif topo15_4320 | psql -d world
raster2pgsql -d -s 4326 -I -C -M -F -t 1x1 topo15_4320_aspect.tif topo15_4320_aspect | psql -d world

# raster stats by basin
for a in {01..12}; do
  psql -d world -c "ALTER TABLE basinatlas_v10_lev${a} ADD COLUMN dem_mean int; UPDATE basinatlas_v10_lev${a} a SET dem_mean = (ST_SummaryStats(rast)).mean FROM topo15_4320 b WHERE ST_Intersects(b.rast, a.shape);"
  psql -d world -c "ALTER TABLE basinatlas_v10_lev${a} ADD COLUMN aspect_mean int; UPDATE basinatlas_v10_lev${a} a SET aspect_mean = (ST_SummaryStats(rast)).mean FROM topo15_4320_aspect b WHERE ST_Intersects(b.rast, a.shape);"
done
```

### Natural Earth

Intersection

```
# get column names
echo $(psql -qAtX -d world -c '\d ne_10m_admin_0_map_subunits' | grep -v "geom" | grep -v "fid" | sed -e 's/|.*//g')

# intersection
psql -d world -c "CREATE TABLE topo15_4320_1000m_polygon_subunits AS SELECT a.amin, a.amax, b.featurecla, b.scalerank, b.labelrank, b.sovereignt, b.sov_a3, b.adm0_dif, b.level, b.type, b.tlc, b.admin, b.adm0_a3, b.geou_dif, b.geounit, b.gu_a3, b.su_dif, b.subunit, b.su_a3, b.brk_diff, b.name, b.name_long, b.brk_a3, b.brk_name, b.brk_group, b.abbrev, b.postal, b.formal_en, b.formal_fr, b.name_ciawf, b.note_adm0, b.note_brk, b.name_sort, b.name_alt, b.mapcolor7, b.mapcolor8, b.mapcolor9, b.mapcolor13, b.pop_est, b.pop_rank, b.pop_year, b.gdp_md, b.gdp_year, b.economy, b.income_grp, b.fips_10, b.iso_a2, b.iso_a2_eh, b.iso_a3, b.iso_a3_eh, b.iso_n3, b.iso_n3_eh, b.un_a3, b.wb_a2, b.wb_a3, b.woe_id, b.woe_id_eh, b.woe_note, b.adm0_iso, b.adm0_diff, b.adm0_tlc, b.adm0_a3_us, b.adm0_a3_fr, b.adm0_a3_ru, b.adm0_a3_es, b.adm0_a3_cn, b.adm0_a3_tw, b.adm0_a3_in, b.adm0_a3_np, b.adm0_a3_pk, b.adm0_a3_de, b.adm0_a3_gb, b.adm0_a3_br, b.adm0_a3_il, b.adm0_a3_ps, b.adm0_a3_sa, b.adm0_a3_eg, b.adm0_a3_ma, b.adm0_a3_pt, b.adm0_a3_ar, b.adm0_a3_jp, b.adm0_a3_ko, b.adm0_a3_vn, b.adm0_a3_tr, b.adm0_a3_id, b.adm0_a3_pl, b.adm0_a3_gr, b.adm0_a3_it, b.adm0_a3_nl, b.adm0_a3_se, b.adm0_a3_bd, b.adm0_a3_ua, b.adm0_a3_un, b.adm0_a3_wb, b.continent, b.region_un, b.subregion, b.region_wb, b.name_len, b.long_len, b.abbrev_len, b.tiny, b.homepart, b.min_zoom, b.min_label, b.max_label, b.label_x, b.label_y, b.ne_id, b.wikidataid, b.name_ar, b.name_bn, b.name_de, b.name_en, b.name_es, b.name_fa, b.name_fr, b.name_el, b.name_he, b.name_hi, b.name_hu, b.name_id, b.name_it, b.name_ja, b.name_ko, b.name_nl, b.name_pl, b.name_pt, b.name_ru, b.name_sv, b.name_tr, b.name_uk, b.name_ur, b.name_vi, b.name_zh, b.name_zht, b.fclass_iso, b.tlc_diff, b.fclass_tlc, b.fclass_us, b.fclass_fr, b.fclass_ru, b.fclass_es, b.fclass_cn, b.fclass_tw, b.fclass_in, b.fclass_np, b.fclass_pk, b.fclass_de, b.fclass_gb, b.fclass_br, b.fclass_il, b.fclass_ps, b.fclass_sa, b.fclass_eg, b.fclass_ma, b.fclass_pt, b.fclass_ar, b.fclass_jp, b.fclass_ko, b.fclass_vn, b.fclass_tr, b.fclass_id, b.fclass_pl, b.fclass_gr, b.fclass_it, b.fclass_nl, b.fclass_se, b.fclass_bd, b.fclass_ua, (ST_Multi(ST_Intersection(ST_Buffer(a.geom,0), (ST_Buffer(b.geom,0)))))::geometry(MultiPolygon,4326) AS geom FROM topo15_4320_1000m_polygon a, ne_10m_admin_0_map_subunits b WHERE ST_Intersects(a.geom, b.geom);"
```

### Geonames

Import

```
# format csv
cat allCountries.txt | tr '"' "'" > allCountries.csv

# create table & prep in psql
CREATE TABLE geonames(geonameid int, name text, asciiname text, altnames text, lat float8, lon float8, featureclass text, featurecode text, countrycode text, cc2 text, admin1 text, admin2 text, admin3 text, admin4 text, population bigint, elevation int, dem int, timezone text, mod_date date);
COPY geonames FROM 'allCountries.csv' CSV DELIMITER E'\t';
SELECT AddGeometryColumn('geonames','geom',4326,'POINT',2);
UPDATE geonames SET geom = ST_SetSRID(ST_MakePoint(lon,lat),4326);
CREATE INDEX geonames_geom_idx ON geonames USING GIST ( geom );
ALTER TABLE geonames ADD COLUMN fid serial PRIMARY KEY;
VACUUM ANALYZE geonames;
CLUSTER geonames USING geonames_geom_idx;
ANALYZE geonames;

# import featurecodes
CREATE TABLE featurecode_en(featurecode text, name text, description text);
COPY featurecode_en FROM 'featureCodes_en.txt' DELIMITER E'\t';
ALTER TABLE geonames ADD COLUMN fcode_en text;
UPDATE geonames a SET fcode_en = b.name FROM featurecode_en b WHERE concat(a.featureclass, '.', a.featurecode) = b.featurecode;
ALTER TABLE geonames ADD COLUMN fcode_desc text;
UPDATE geonames a SET fcode_desc = b.description FROM featurecode_en b WHERE concat(a.featureclass, '.', a.featurecode) = b.featurecode;

# import country info
CREATE TABLE countryinfo(iso text, iso3 text, iso_numeric int, fips text, country text, capital text, area float, population int, continent text, tld text, currencycode text, currencyname text, phone text, postalcodeformat text, postalcoderegex text, languages text, geonameid int, neighbours text, equivalentfips text);
COPY countryinfo FROM 'countryInfo.txt' DELIMITER E'\t' CSV HEADER;

# import alternate names
CREATE TABLE alternatenames(alternatenameid int, geonameid int, isolanguage text, alternatename text, ispreferredname text, isshortname text, iscolloquial text, ishistoric text, date_from text, date_to text);
COPY alternatenames FROM 'alternateNamesV2.txt' DELIMITER E'\t';

# import language codes and add local name
CREATE TABLE languagecodes(iso_639_3 text, iso_639_2 text, iso_639_1 text, languagename text);
COPY languagecodes FROM 'iso-languagecodes.txt' DELIMITER E'\t' CSV HEADER;
UPDATE geonames a SET localname = c.alternatename FROM countryinfo b, alternatenames c WHERE a.countrycode = b.iso AND a.geonameid = c.geonameid AND regexp_replace(regexp_replace(b.languages, '\-.*$', ''),',.*$','') = c.isolanguage;
```

Top 3 languages into array

```
ALTER TABLE countryinfo ADD COLUMN languagenames text array;
UPDATE countryinfo a SET languagenames[1] = regexp_replace(regexp_replace(b.languagename, ' \(.*\)', ''), 'Modern ', '') FROM languagecodes b WHERE SPLIT_PART(regexp_replace(a.languages, '-'||a.iso, '', 'g'), ',', 1) = b.iso_639_1 OR SPLIT_PART(a.languages, ',', 1) = b.iso_639_3;
UPDATE countryinfo a SET languagenames[2] = regexp_replace(regexp_replace(b.languagename, ' \(.*\)', ''), 'Modern ', '') FROM languagecodes b WHERE SPLIT_PART(regexp_replace(a.languages, '-'||a.iso, '', 'g'), ',', 2) = b.iso_639_1 OR SPLIT_PART(a.languages, ',', 2) = b.iso_639_3;
UPDATE countryinfo a SET languagenames[3] = regexp_replace(regexp_replace(b.languagename, ' \(.*\)', ''), 'Modern ', '') FROM languagecodes b WHERE SPLIT_PART(regexp_replace(a.languages, '-'||a.iso, '', 'g'), ',', 3) = b.iso_639_1 OR SPLIT_PART(a.languages, ',', 3) = b.iso_639_3;
#rm -f localname.sql
#echo $(psql -d world -c "\COPY (SELECT DISTINCT(iso_639_1) FROM places) TO STDOUT;") | tr ' ' '\n' | while read lang; do echo 'UPDATE places SET localname = name_'${lang} WHERE iso_639_1 = "'"${lang}"'"';' >> $PWD/../data/localname.sql; done
#UPDATE places a SET localname = b.alternatename FROM alternatenames b WHERE a.geonameid = b.geonameid AND a.iso_639_1 = b.isolanguage AND b.isolanguage NOT IN ('','iata','link','post','unlc','wkdt');
#echo $(psql -d world -c "\COPY (SELECT DISTINCT(iso_639_1) FROM places) TO STDOUT;") | tr ' ' '\n' | while read lang; do echo 'UPDATE places SET localname = name_'${lang} WHERE iso_639_1 = ${lang}; done
```

List & order places in extent

```
# alphabetical
psql -d world -c "WITH b AS (SELECT b.longitude, b.latitude, array_agg(a.name ORDER BY b.page, a.name) places FROM ne_10m_populated_places_3857 a, worldatlas_pages_3857 b, worldatlas_extents c WHERE a.scalerank IN (0,1,2,3,4) AND b.page IS NOT NULL AND b.longitude = c.longitude AND b.latitude = c.latitude AND ST_Intersects(a.geom, ST_MakeEnvelope(c.x_min,c.y_min,c.x_max,c.y_max,3857)) GROUP BY b.page, b.longitude, b.latitude) UPDATE worldatlas_pages_3857 a SET places = b.places FROM b WHERE a.longitude = b.longitude AND a.latitude = b.latitude;"

# by pop
psql -d world -c "WITH b AS (SELECT b.longitude, b.latitude, array_agg(a.name ORDER BY b.page, a.pop_max DESC) places FROM ne_10m_populated_places_3857 a, worldatlas_pages_3857 b, worldatlas_extents c WHERE a.scalerank IN (0,1,2,3,4) AND b.page IS NOT NULL AND b.longitude = c.longitude AND b.latitude = c.latitude AND ST_Intersects(a.geom, ST_MakeEnvelope(c.x_min,c.y_min,c.x_max,c.y_max,3857)) GROUP BY b.page, b.longitude, b.latitude) UPDATE worldatlas_pages_3857 a SET places = b.places FROM b WHERE a.longitude = b.longitude AND a.latitude = b.latitude;"

# mts
psql -d world -c "alter table worldatlas_pages_3857 add column geonames_mt text;"
psql -d world -c "WITH b AS (SELECT b.longitude, b.latitude, array_agg(a.name || ' ' || coalesce(a.elevation,a.dem) || 'm (' || CASE WHEN a.lon < 0 THEN round(a.lon::numeric,1)*-1 || 'W' ELSE round(a.lon::numeric,1) || 'E' END || '/' || CASE WHEN a.lat < 0 THEN round(a.lat::numeric,1)*-1 || 'S' ELSE round(a.lat::numeric,1) || 'N' END || ')' ORDER BY a.dem DESC) mts FROM geonames_mt_3857 a, worldatlas_pages_3857 b, worldatlas_extents c WHERE b.page IS NOT NULL AND b.longitude = c.longitude AND b.latitude = c.latitude AND ST_Intersects(a.geom, ST_MakeEnvelope(c.x_min,c.y_min,c.x_max,c.y_max,3857)) GROUP BY b.page, b.longitude, b.latitude) UPDATE worldatlas_pages_3857 a SET geonames_mt = b.mts FROM b WHERE a.longitude = b.longitude AND a.latitude = b.latitude;"
```

Rank places with rank() or row_number()

```
# by place
ALTER TABLE geonames ADD COLUMN pop_rank int; WITH b AS (SELECT fid, RANK() OVER (PARTITION BY countrycode ORDER BY population DESC) pop_rank FROM geonames WHERE featurecode LIKE 'PPL%' AND name NOT IN ('Brooklyn','Queens','Manhattan','The Bronx')) UPDATE geonames a SET pop_rank = b.pop_rank FROM b WHERE a.fid = b.fid;
ALTER TABLE geonames ADD COLUMN mt_rank int; WITH b AS (SELECT fid, RANK() OVER (PARTITION BY countrycode ORDER BY dem DESC) mt_rank FROM geonames WHERE featurecode = 'MT') UPDATE geonames a SET mt_rank = b.mt_rank FROM b WHERE a.fid = b.fid;

# by extent
psql -d world -c "ALTER TABLE geonames_mt_3857 ADD COLUMN rank int;"
psql -d world -c "WITH b AS (SELECT b.fid, ROW_NUMBER () OVER (PARTITION BY CONCAT(c.longitude::text, c.latitude::text) ORDER BY b.dem DESC) rank FROM worldatlas_pages_3857 a, geonames_mt_3857 b, worldatlas_extents c WHERE a.page IS NOT NULL AND a.longitude = c.longitude AND a.latitude = c.latitude AND ST_Intersects(b.geom, ST_MakeEnvelope(c.x_min,c.y_min,c.x_max,c.y_max,3857))) UPDATE geonames_mt_3857 a SET rank = b.rank FROM b WHERE a.fid = b.fid;"
```

Aggregate pop rank, mt rank

```
CREATE TABLE geonames_pop_rank AS SELECT countrycode, STRING_AGG(CONCAT(name, '.....', TO_CHAR(population::int, 'FM9,999,999,999')), ';' ORDER BY population DESC) pop_ranks FROM geonames WHERE pop_rank <= 5 GROUP BY countrycode;
CREATE TABLE geonames_mt_rank AS SELECT countrycode, STRING_AGG(CONCAT(name, '.....', TO_CHAR(coalesce(elevation, dem)::int, 'FM9,999,999,999'), 'm'), ';' ORDER BY dem DESC) mt_ranks FROM geonames WHERE mt_rank <= 3 GROUP BY countrycode;
CREATE TABLE geonames_top_rank AS SELECT * FROM geonames WHERE pop_rank <=5 OR mt_rank <= 3 OR featurecode IN ('PPLC');
```

Export

```
ogr2ogr -overwrite -update -f "SQLite" -sql "SELECT a.featurecode_name, a.featureclass, (SELECT b.geom FROM contour10m_segments1_5 AS b ORDER BY b.geom <-> ST_GeometryN(ST_Collect(a.geom),1) LIMIT 1) FROM allcountries AS a WHERE a.geom && ST_MakeEnvelope(-123,41,-111,51) AND a.featureclass IN ('T','H','U','V') GROUP BY a.featurecode_name, a.featureclass" export.sqlite -nln geonames -nlt LINESTRING PG:"dbname=topo15
```

### Koppen

```
# import koppen
ogr2ogr -nln koppen -nlt POLYGON -lco precision=NO -overwrite -lco ENCODING=UTF-8 --config PG_USE_COPY YES -f PGDump /vsistdout/ c2076_2100.shp c2076_2100 | psql -d world -f -

# add names
cat > legend.csv <<- EOM
11	Af	Tropical rainforest
12	Am	Tropical monsoon
13	As	Tropical savanna dry summer
14	Aw	Tropical savanna dry winter 
21	BWk	Arid
22	BWh	Arid
26	BSk	Semi-arid steppe
27	BSh	Semi-arid steppe
31	Cfa	Humid subtropical
32	Cfb	Oceanic
33	Cfc	Subpolar oceanic
34	Csa	Mediterranean hot summer
35	Csb	Mediterranean warm-cool summer
36	Csc	Mediterranean cold summer
37	Cwa	Humid subtropical dry winter
38	Cwb	Subtropical highland dry winter
39	Cwc	Subpolar oceanic dry winter
41	Dfa	Continental hot summer
42	Dfb	Continental warm summer
43	Dfc	Subarctic boreal
44	Dfd	Subarctic boreal severe winter
45	Dsa	Continental hot summer 
46	Dsb	Continental warm summer
47	Dsc	Subarctic boreal
48	Dsd	Subarctic boreal severe winter
49	Dwa	Continental hot summer
50	Dwb	Continental warm summer
51	Dwc	Subarctic boreal
52	Dwd	Subarctic boreal severe winter
61	EF	Ice cap
62	ET	Tundra
EOM

# join shapes and names
CREATE TABLE koppen_name(gridcode bigint, abbrev text, name text);
COPY koppen_name FROM 'legend.csv' DELIMITER E'\t';
ALTER TABLE koppen ADD COLUMN name text;
UPDATE koppen a SET name = b.name FROM koppen_name b WHERE a.gridcode = b.gridcode;
```

### GBIF

Import vernacularname

```
CREATE TABLE vernacularname(taxonid int, vernacularname varchar, language varchar, country varchar, countryCode varchar, sex varchar, lifestage varchar, source varchar);
COPY vernacularname FROM 'VernacularName.tsv' DELIMITER E'\t' CSV HEADER;
CREATE TABLE vernacularname_agg AS SELECT taxonid,string_agg(vernacularname,';') FROM vernacularname GROUP BY taxonid;
```

Import distribution

```
sed -i 's/"//g' Distribution.tsv
CREATE TABLE distribution(
taxonid int, locationid text, locality text, country text, countrycode text, locationremarks text, establishmentmeans text, lifestage text, occurrencestatus text, threatstatus text, source text);
COPY distribution FROM 'Distribution.tsv' DELIMITER E'\t' CSV HEADER;
```

Import dataset

```
sed -i '1 s/order/ordername/' ibol.csv
CREATE TABLE ibol(gbifid bigint, datasetkey text, occurrenceid text, kingdom text, phylum text, class text, ordername text, family text, genus text, species text, infraspecificepithet text, taxonrank text, scientificname text, countrycode text, locality text, publishingorgkey text, decimallatitude float8, decimallongitude float8, coordinateuncertaintyinmeters float8, coordinateprecision float8, elevation float8, elevationaccuracy float8, depth float8, depthaccuracy float8, eventdate date, day int, month int, year int, taxonkey int, specieskey int, basisofrecord text, institutioncode text, collectioncode text, catalognumber text, recordnumber text, identifiedby text, dateidentified text, license text, rightsholder text, recordedby text, typestatus text, establishmentmeans text, lastinterpreted text, mediatype text, issue text);
COPY ibol FROM 'ibol.csv' DELIMITER E'\t' CSV HEADER;
ALTER TABLE ibol ADD PRIMARY KEY (gbifid);
ALTER TABLE ibol ADD COLUMN geom GEOMETRY(POINT, 4326);
ALTER TABLE ibol ALTER COLUMN geom SET STORAGE EXTERNAL;
UPDATE ibol SET geom = ST_SetSrid(ST_MakePoint(decimallongitude, decimallatitude), 4326);
CREATE INDEX ibol_gid ON ibol USING GIST (geom);

# join
ALTER TABLE ibol ADD COLUMN vernacularname text;
UPDATE ibol a SET vernacularname = b.string_agg FROM vernacularname_agg b WHERE b.taxonid = a.taxonkey;
```

Export gbif as labels on contours

```
extent="-123,41,-111,51"
ogr2ogr -overwrite -f "SQLite" -dsco SPATIALITE=YES -sql "SELECT a.vname_en, a.datasetkey, a.kingdom, a.phylum, a.class, a.order, a.family, a.genus, a.species, a.scientificname, (SELECT b.geom FROM contour10m_seg1_5 AS b ORDER BY b.geom <-> ST_GeometryN(ST_Collect(a.geom),1) LIMIT 1) FROM nmnh AS a WHERE a.geom && ST_MakeEnvelope(${extent}) GROUP BY a.vname_en, a.datasetkey, a.kingdom, a.phylum, a.class, a.order, a.family, a.genus, a.species, a.scientificname" gbif_extract.sqlite -nln gbif -nlt LINESTRING PG:"dbname=contours"
```

Export gbif one-to-many points

```
extent="-123,41,-111,51"
ogr2ogr -overwrite -f "SQLite" -dsco SPATIALITE=YES -sql "SELECT a.geom, a.vname_en, a.datasetkey, a.kingdom, a.phylum, a.class, a.order, a.family, a.genus, a.species, a.scientificname, (SELECT CAST(b.fid AS int) AS contourid FROM contour10m_seg1_5 AS b ORDER BY b.geom <-> a.geom LIMIT 1) FROM nmnh AS a WHERE a.geom && ST_MakeEnvelope(${extent})" gbif_extract.sqlite -nln gbif -nlt POINT PG:"dbname=contours"
```

### GHCN

Prep files

```
./ghcn2csv-converter.py -f daily -i ghcnd_gsn.dly -o ghcnd_gsn.csv
cat ghcnd-stations.txt | awk -v OFS='\t' '{print substr($0,1,12), substr($0,13,8), substr($0,22,9), substr($0,32,6), substr($0,39,2), substr($0,42,30), substr($0,73,3), substr($0,77,3), substr($0,81,5)}' | sed 's/ *\t */\t/g' > ghcnd-stations.csv
```

Create table

```
# import data
CREATE TABLE ghcn(id varchar,year integer,month integer,element varchar,value1 Integer,mflag1 varchar,qflag1 varchar,sflag1 varchar,value2 integer,mflag2 varchar,qflag2 varchar,sflag2 varchar,value3 integer,mflag3 varchar,qflag3 varchar,sflag3 varchar,value4 integer,mflag4 varchar,qflag4 varchar,sflag4 varchar,value5 integer,mflag5 varchar,qflag5 varchar,sflag5 varchar,value6 integer,mflag6 varchar,qflag6 varchar,sflag6 varchar,value7 integer,mflag7 varchar,qflag7 varchar,sflag7 varchar,value8 integer,mflag8 varchar,qflag8 varchar,sflag8 varchar,value9 integer,mflag9 varchar,qflag9 varchar,sflag9 varchar,value10 integer,mflag10 varchar,qflag10 varchar,sflag10 varchar,value11 integer,mflag11 varchar,qflag11 varchar,sflag11 varchar,value12 integer,mflag12 varchar,qflag12 varchar,sflag12 varchar,value13 integer,mflag13 varchar,qflag13 varchar,sflag13 varchar,value14 integer,mflag14 varchar,qflag14 varchar,sflag14 varchar,value15 integer,mflag15 varchar,qflag15 varchar,sflag15 varchar,value16 integer,mflag16 varchar,qflag16 varchar,sflag16 varchar,value17 integer,mflag17 varchar,qflag17 varchar,sflag17 varchar,value18 integer,mflag18 varchar,qflag18 varchar,sflag18 varchar,value19 integer,mflag19 varchar,qflag19 varchar,sflag19 varchar,value20 integer,mflag20 varchar,qflag20 varchar,sflag20 varchar,value21 integer,mflag21 varchar,qflag21 varchar,sflag21 varchar,value22 integer,mflag22 varchar,qflag22 varchar,sflag22 varchar,value23 integer,mflag23 varchar,qflag23 varchar,sflag23 varchar,value24 integer,mflag24 varchar,qflag24 varchar,sflag24 varchar,value25 integer,mflag25 varchar,qflag25 varchar,sflag25 varchar,value26 integer,mflag26 varchar,qflag26 varchar,sflag26 varchar,value27 integer,mflag27 varchar,qflag27 varchar,sflag27 varchar,value28 integer,mflag28 varchar,qflag28 varchar,sflag28 varchar,value29 integer,mflag29 varchar,qflag29 varchar,sflag29 varchar,value30 integer,mflag30 varchar,qflag30 varchar,sflag30 varchar,value31 integer,mflag31 varchar,qflag31 varchar,sflag31 varchar);
COPY ghcn FROM 'ghcnd_gsn.csv' DELIMITER ',' CSV HEADER;
ALTER TABLE ghcn ADD COLUMN fid serial primary key, ADD COLUMN station varchar, ADD COLUMN latitude real, ADD COLUMN longitude real, ADD COLUMN elevation real, ADD COLUMN geom GEOMETRY(POINT, 4326);
ALTER TABLE ghcn ALTER COLUMN geom SET STORAGE EXTERNAL;

# import stations
CREATE TABLE stations(id varchar, latitude real, longitude real, elevation real, state varchar, name varchar, gsn_flag varchar, hcn_flag varchar, wmo_id varchar);
COPY stations FROM 'ghcnd-stations.csv' DELIMITER E'\t';
ALTER TABLE stations ADD COLUMN geom GEOMETRY(POINT, 4326);
UPDATE stations SET geom = ST_SetSrid(ST_MakePoint(longitude, latitude), 4326);

# join
UPDATE ghcn a SET station = b.name FROM stations b WHERE a.id = b.id;
UPDATE ghcn a SET latitude = b.latitude FROM stations b WHERE a.id = b.id;
UPDATE ghcn a SET latitude = b.longitude FROM stations b WHERE a.id = b.id;
UPDATE ghcn a SET latitude = b.elevation FROM stations b WHERE a.id = b.id;
UPDATE ghcn SET geom = ST_SetSrid(ST_MakePoint(longitude, latitude), 4326);
CREATE INDEX ghcn_gid ON ghcn USING GIST (geom);
```
