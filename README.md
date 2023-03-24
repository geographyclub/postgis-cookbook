# postgis-cookbook

## TABLE OF CONTENTS

1. [General commands](#1-General-commands)  
2. [Dataset examples](#2-Dataset-examples)  

## 1. General commands

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

Add keys, index

`ALTER TABLE wwf_ecoregion ADD COLUMN fid serial primary key;`

`ALTER TABLE places_nogeom ADD PRIMARY KEY (fid);`

`CREATE INDEX contour100m_poly_gid ON contour100m_poly USING GIST (geom);`

Cluster

```
VACUUM ANALYZE geosnap;
CLUSTER geosnap USING geosnap_gid;
ANALYZE geosnap;
```

Decompress

`ALTER TABLE allcountries ALTER COLUMN geom SET STORAGE EXTERNAL;`

Add epsg/srid (see spatialreference.org)

```
INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) values ( 953027, 'esri', 53027, '+proj=eqdc +lat_0=0 +lon_0=0 +lat_1=60 +lat_2=60 +x_0=0 +y_0=0 +a=6371000 +b=6371000 +units=m +no_defs ', 'PROJCS["Sphere_Equidistant_Conic",GEOGCS["GCS_Sphere",DATUM["Not_specified_based_on_Authalic_Sphere",SPHEROID["Sphere",6371000,0]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["Equidistant_Conic"],PARAMETER["False_Easting",0],PARAMETER["False_Northing",0],PARAMETER["Central_Meridian",0],PARAMETER["Standard_Parallel_1",60],PARAMETER["Standard_Parallel_2",60],PARAMETER["Latitude_Of_Origin",0],UNIT["Meter",1],AUTHORITY["EPSG","53027"]]');
```

```
INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) values ( 954031, 'esri', 54031, '+proj=tpeqd +lat_1=0 +lon_1=0 +lat_2=60 +lon_2=60 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs ', 'PROJCS["World_Two_Point_Equidistant",GEOGCS["GCS_WGS_1984",DATUM["WGS_1984",SPHEROID["WGS_1984",6378137,298.257223563]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["Two_Point_Equidistant"],PARAMETER["False_Easting",0],PARAMETER["False_Northing",0],PARAMETER["Latitude_Of_1st_Point",0],PARAMETER["Latitude_Of_2nd_Point",60],PARAMETER["Longitude_Of_1st_Point",0],PARAMETER["Longitude_Of_2nd_Point",60],UNIT["Meter",1],AUTHORITY["EPSG","54031"]]');
```

```
INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) values ( 53029, 'ESRI', 53029, '+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m +no_defs ', 'PROJCS["Sphere_Van_der_Grinten_I",GEOGCS["GCS_Sphere",DATUM["Not_specified_based_on_Authalic_Sphere",SPHEROID["Sphere",6371000,0]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["VanDerGrinten"],PARAMETER["False_Easting",0],PARAMETER["False_Northing",0],PARAMETER["Central_Meridian",0],UNIT["Meter",1],AUTHORITY["EPSG","53029"]]');
```

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

List tables

`COPY (SELECT * FROM pg_catalog.pg_tables) TO STDOUT;`

`COPY (SELECT table_name, string_agg(column_name, ', ' order by ordinal_position) as columns FROM information_schema.columns WHERE table_name LIKE 'ne_10m%' GROUP BY table_name;) TO STDOUT`

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

Boolean type

`SELECT b.name, COUNT(b.name) FROM points_us a, acs_2019_5yr_place b WHERE ST_Intersects(a.wkb_geometry, b."Shape") AND ((a.other_tags->'%amenity%')::boolean) GROUP BY b.name ORDER BY COUNT(b.name);`

Replace string

`UPDATE <table> SET <field> = replace(<field>, 'cat', 'dog');`

Concat strings

`SELECT CONCAT(b.id,';',b.station,';',b.latitude,';',b.longitude,';',b.elevation) FROM ghcn b WHERE a.fid = b.contour100m_id;`

Split part

`UPDATE countryinfo a SET language1 = b.languagename FROM languagecodes b WHERE SPLIT_PART(regexp_replace(a.languages, '-'||a.iso, '', 'g'), ',', 1) = b.iso_639_1 OR SPLIT_PART(a.languages, ',', 1) = b.iso_639_3;`

Split + replace

`SELECT wx, REGEXP_REPLACE(REGEXP_REPLACE(wx,'(\w\w)','\1 ','g'),' +',' ','g') FROM metar;`

Copy db to db

`ogr2ogr -overwrite -lco precision=NO --config PG_USE_COPY YES -f PGDump /vsistdout/ PG:dbname=contours fishbase | psql -d gbif -f -`

Copy table to table

`CREATE TABLE ne_10m_admin_0_countries_3857 AS TABLE ne_10m_admin_0_countries;`

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

`pgsql2shp -f "test" -u steve weather "SELECT metar.station_id,metar.temp_c,ST_MakeLine(metar.geom,metar.translated) FROM metar_20180320_183305 AS metar;`

Export to csv

`psql -d grids -c "COPY (SELECT fid,scalerank,name,adm1name,round(longitude::numeric,2),round(latitude::numeric,2) FROM places) TO STDOUT WITH CSV DELIMITER '|';" > places.csv`

`psql -d grids -c "COPY (SELECT fid, wikidata_id, enwiki_title FROM unum WHERE enwiki_title IS NOT NULL) TO STDOUT WITH CSV DELIMITER E'\t';" > unum_wiki.csv`

Get angle (degrees)

`SELECT ST_Azimuth(ST_Startpoint(way), ST_Endpoint(way))/(2*pi())*360 FROM planet_osm_line;`

Get road angle

`UPDATE city_points a SET road_angle = ST_Azimuth(a.geom,ST_ClosestPoint(a.geom,b.geom))/(2*pi())*360 FROM city_roads b;`

Label angle 4326 -> 53209 

```
ALTER TABLE countries110m ADD COLUMN angle53029 int;
UPDATE countries110m SET angle53029 = ST_Azimuth(ST_Transform(ST_Centroid(geom),'EPSG:4326','+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m no_defs'),ST_Transform(ST_Translate(ST_Centroid(geom),0.1,0),'EPSG:4326','+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m no_defs'))/(2*pi())*360;
UPDATE marine110m SET angle53029 = ST_Azimuth(ST_Transform(ST_Centroid(ST_Buffer(geom,0)),'EPSG:4326','+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m no_defs'),ST_Transform(ST_Intersection(ST_MakeEnvelope(-175, -85, 175, 85, 4326),ST_Translate(ST_Centroid(ST_Buffer(geom,0)),0.1,0)),'EPSG:4326','+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m no_defs'))/(2*pi())*360;
```

Random select

`CREATE TABLE contour100m_points1000 AS SELECT * FROM contour100m_points TABLESAMPLE SYSTEM ((1000 * 100) / 5100000.0);`

`SELECT * FROM contour100m_raw WHERE fid IN (SELECT fid FROM contour100m_raw ORDER BY RANDOM() LIMIT 100000);`

Distinct select

`SELECT DISTINCT ON (taxonid) taxonid, vernacularname FROM gbif_vernacular WHERE language IN ('en') ORDER BY taxonid, vernacularname;`

Group and count

`SELECT featurecode,COUNT(featurecode) FROM superior_lines WHERE featureclass IN ('T') GROUP BY featurecode ORDER BY COUNT(featurecode) ASC;`

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

Buffer

`UPDATE places_voronoi_buffer1 SET geom = st_buffer(geom, 1, 'endcap=square join=miter');`

Multibuffers

`CREATE TABLE places_buffers AS SELECT a.name, '0' AS buffer, b.geom FROM places a, grid02 b WHERE ST_Intersects(a.geom, b.geom) UNION SELECT a.name, '01' AS buffer, b.geom FROM places a, grid02 b WHERE ST_Intersects(ST_Buffer(a.geom,0.1), b.geom);`

Dissolve buffers

`CREATE TABLE hydroriver_buffer1 AS WITH buffer AS (SELECT ST_Buffer(shape,upland_skm*0.000001) geom FROM hydroriver WHERE upland_skm >= 10000) SELECT (ST_Dump(ST_Union(geom))).geom::GEOMETRY(POLYGON,4326) geom FROM buffer;`

Dissolve/union

`CREATE TABLE limw_dissolve AS SELECT xx_name, ST_CollectionExtract(ST_Union(geom),3) geom FROM limw GROUP BY xx_name;`

`CREATE TABLE contour100m_dissolve AS SELECT (ST_Dump(ST_Union(geom))).geom::GEOMETRY(LINESTRING,4326) geom from contour100m;`

`UPDATE grid04_countries a SET geom = (SELECT ST_Multi(ST_Union(b.geom))::GEOMETRY(MULTIPOLYGON, 4326) FROM grid04 b WHERE ST_Intersects(a.geom, b.geom));`

`CREATE TABLE wwf_ecoregion AS SELECT eco_name, realm_name, biome_name, ST_Union(geom) AS geom FROM wwf_ecoregion_test GROUP BY eco_name, realm_name, biome_name;`

Aggregate by column

`CREATE TABLE vernacularname_agg AS SELECT taxonid,string_agg(vernacularname,';') FROM vernacularname GROUP BY taxonid;`

`UPDATE grid02 a SET places = (SELECT string_agg(b.name, ',' ORDER BY b.scalerank) FROM places b WHERE ST_Intersects(a.geom, b.geom));`

Aggregate by geom

`CREATE TABLE places_label_italy AS SELECT STRING_AGG(name, ',' ORDER BY ST_X(geom)) AS names, ST_SetSRID(ST_MakePoint(ST_XMin(ST_Multi(ST_Union(geom))), ST_Y(geom)), 4326)::geometry(POINT, 4326) AS geom FROM places_snap02 WHERE adm0name IN ('Italy') GROUP BY ST_Y(geom);`

Nearest neighbor

`UPDATE gebco_contour1 a SET geom = (SELECT b.geom FROM contour10m_segment1 b WHERE ST_DWithin(a.geom,b.geom,1) ORDER BY a.geom <-> b.geom LIMIT 1);`

Extent

`SELECT a.geonameid,a.name,a.asciiname,a.altnames,a.lat,a.lon,a.featureclass,a.featurecode,a.countrycode,a.admin1,a.admin2,a.admin3,a.admin4,a.population,a.elevation,a.dem,a.timezone,a.featurecode_name,a.featurecode_notes, (SELECT b.geom FROM contour10m_segments AS b ORDER BY b.geom <-> ST_Union(ST_Intersect(a.geom)) LIMIT 1) FROM allcountries AS a WHERE a.geom && ST_MakeEnvelope(-94,43,-83,52);`

`SELECT a.gbifid, a.kingdom, a.phylum, a.class, a.order, a.family, a.genus, a.species, a.scientificname, a.decimallatitude, a.decimallongitude, a.elevation, a.depth, (SELECT b.geom FROM contour10m_segments AS b ORDER BY b.geom <-> a.geom LIMIT 1) FROM nmnh AS a WHERE a.geom && ST_MakeEnvelope(-94,43,-83,52);`

Group by median

`SELECT a.species, (SELECT b.geom FROM contour10m_segments AS b ORDER BY b.geom <-> ST_GeometricMedian(ST_Collect(a.geom)) LIMIT 1) FROM insdc AS a WHERE a.geom && ST_MakeEnvelope(-94,43,-83,52) GROUP BY a.species;`

Group by n

`SELECT a.featurecode_name, a.featureclass, (SELECT b.geom FROM contour10m_segments AS b ORDER BY b.geom <-> ST_GeometryN(ST_Collect(a.geom),1) LIMIT 1) FROM allcountries AS a WHERE a.geom && ST_MakeEnvelope(-94,43,-83,52) AND a.featureclass IN ('T','H','U','V') GROUP BY a.featurecode_name, a.featureclass;`

Group by single point

`SELECT * FROM tor_female WHERE CTUID = (SELECT CTUID FROM toronto_points_ct ORDER BY geom <-> ST_SetSRID(ST_MakePoint(-79.40,43.67),4326) LIMIT 1);`

Nearest METARS station

`SELECT m.station_id FROM ${mytable} AS m ORDER BY m.geom <-> p.geom LIMIT 1;`

Nearest neighbor with cte

`CREATE TABLE labels_italy AS WITH points AS (SELECT (ST_DumpPoints(b.geom)).geom::GEOMETRY(point, 4326) as geom FROM countries b WHERE name IN ('Italy')) SELECT a.name, (SELECT b.geom FROM points b ORDER BY b.geom <-> a.geom LIMIT 1) FROM places a WHERE adm0name IN ('Italy');`

Cross join

`CREATE TABLE contour10m_classt AS SELECT b.fcode_en_name, a.geom FROM contour10m_segment1 a CROSS JOIN LATERAL (SELECT fcode_en_name, geom FROM allcountries WHERE featureclass = 'T' AND a.elev >= 0 AND ST_DWithin(a.geom,geom,0.1) ORDER BY a.geom <-> geom LIMIT 1) b;`

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

```
SELECT ST_Extent(way) FROM planet_osm_polygon;
SELECT ST_ExteriorRing(ST_Envelope(ST_Collect(GEOMETRY))) FROM contour10;
SELECT ST_Envelope(ST_Collect(GEOMETRY)) FROM contour10;
```

Make grid (world)

`CREATE TABLE grid1 AS SELECT (ST_PixelAsPolygons(ST_AddBand(ST_MakeEmptyRaster(360,180,0,0,1,1,0,0,4326), '8BSI'::text, 1, 0), 1, false)).geom::geometry(Polygon,4326) AS geom;`

Make grid from extent

`CREATE TABLE grid0001 AS SELECT (ST_PixelAsPolygons(ST_AddBand(ST_MakeEmptyRaster((SELECT ((ST_XMax(ST_Extent(way))-ST_XMin(ST_Extent(way)))/0.001)::numeric::integer FROM planet_osm_polygon), (SELECT ((ST_YMax(ST_Extent(way))-ST_YMin(ST_Extent(way)))/0.001)::numeric::integer FROM planet_osm_polygon), (SELECT ST_XMin(ST_Extent(way)) FROM planet_osm_polygon), (SELECT ST_YMin(ST_Extent(way)) FROM planet_osm_polygon), 0.001, 0.001, 0, 0, 4326), '8BSI'::text, 1, 0), 1, false)).geom::geometry(Polygon,4326) AS geom;`

Make triangles

`CREATE TABLE hood_voronoi AS SELECT (ST_DUMP(ST_VoronoiPolygons(ST_Collect(p.way)))).geom FROM planet_osm_point AS p WHERE place IN ('neighbourhood');`

`CREATE TABLE places_delaunay AS SELECT (ST_Dump(ST_DelaunayTriangles(ST_Union(geom),0.001,1))).geom::geometry(LINESTRING,4326) AS geom FROM places;`

Polygonize

`CREATE TABLE contour10m_snap01_poly AS SELECT elev, ST_Collect(a.geom) AS geom FROM (SELECT elev,(ST_Dump(geom)).geom AS geom FROM contour10m_snap01) AS a GROUP BY elev;`

`CREATE TABLE contour100m_poly AS SELECT fid, elev, (ST_Dump(ST_MakePolygon(geom))).geom::geometry(POLYGON,4326) AS geom FROM contour100m WHERE ST_IsClosed(geom);`

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

## 2. Dataset examples


