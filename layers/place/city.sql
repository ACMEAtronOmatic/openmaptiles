-- etldoc: layer_city[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_city | <z2_14> z2-z14+" ] ;

-- etldoc: osm_city_point -> layer_city:z2_14
CREATE OR REPLACE FUNCTION layer_city(bbox geometry, zoom_level int, pixel_width numeric)
    RETURNS TABLE
            (
                osm_id   bigint,
                geometry geometry,
                name     text,
                name_en  text,
                name_de  text,
                tags     hstore,
                place    city_place,
                "rank"   int,
                capital  int
            )
AS
$$
SELECT *
FROM (
         SELECT osm_id,
                geometry,
                name,
                COALESCE(NULLIF(name_en, ''), name) AS name_en,
                COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
                tags,
                place,
                "rank",
                normalize_capital_level(capital) AS capital
         FROM osm_city_point
         WHERE geometry && bbox
           AND ((zoom_level = 2 AND "rank" = 1)
             OR (zoom_level BETWEEN 3 AND 7 AND "rank" <= zoom_level + 1)
             )
         UNION ALL
         SELECT osm_id,
                geometry,
                name,
                COALESCE(NULLIF(name_en, ''), name) AS name_en,
                COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
                tags,
                place,
                COALESCE("rank", gridrank + 10),
                normalize_capital_level(capital) AS capital
         FROM (
                  SELECT osm_id,
                         geometry,
                         name,
                         COALESCE(NULLIF(name_en, ''), name) AS name_en,
                         COALESCE(NULLIF(name_de, ''), name, name_en) AS name_de,
                         tags,
                         place,
                         "rank",
                         capital,
                         row_number() OVER (
                             PARTITION BY LabelGrid(geometry, 128 * pixel_width)
                             ORDER BY "rank" ASC NULLS LAST,
                                 place ASC NULLS LAST, -- place here is type of place, one of 'city', 'town', 'village', 'hamlet', 'suburb', 'quarter', 'neighbourhood', 'isolated_dwelling'
                                 population DESC NULLS LAST,
                                 length(name) ASC
                             )::int AS gridrank
                  FROM osm_city_point
                  WHERE geometry && bbox
                    AND ((zoom_level BETWEEN 4 AND 7 AND place <= 'town'::city_place -- adding cities and towns for zooms 4-7 to intermediate results so that they can be included in the outer layer query
                      OR (zoom_level BETWEEN 8 AND 10 AND place <= 'village'::city_place)
                      OR (zoom_level BETWEEN 11 AND 13 AND place <= 'suburb'::city_place)
                      OR (zoom_level >= 14)
                      ))
              ) AS ranked_places
         WHERE (zoom_level BETWEEN 4 AND 8 AND (gridrank <= 15 OR "rank" IS NOT NULL)) -- changing from 4 to 15 to catch places that are lower down the gridranking for zooms 4 - 12
            OR (zoom_level = 9 AND (gridrank <= 15 OR "rank" IS NOT NULL))
            OR (zoom_level = 10 AND (gridrank <= 15 OR "rank" IS NOT NULL))
            OR (zoom_level BETWEEN 11 AND 12 AND (gridrank <= 15 OR "rank" IS NOT NULL))
            OR (zoom_level >= 13)
     ) AS city_all;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;
