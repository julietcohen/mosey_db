BEGIN TRANSACTION;

--NOTES:
--  TEXT should be used for date, not NUMERIC
--  INTEGER is used for boolean

CREATE TABLE IF NOT EXISTS `tag` (
	`tag_id`	INTEGER PRIMARY KEY,
	`local_identifier`	INTEGER,
	`manufacturer_name`	TEXT,
	`beacon_frequency`	REAL,
	`model`	TEXT,
	`processing_type`	TEXT,
	`serial_no`	INTEGER,
	`tag_failure_comments`	TEXT,
	`tag_production_date`	TEXT,
	`weight`	REAL,
	`comments`	TEXT
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS `study` (
	`study_id`	REAL PRIMARY KEY,
	`study_name`	TEXT,
	`principal_investigator_name`	TEXT,
	`principal_investigator_email`	TEXT,
	`principal_investigator_address`	TEXT,
	`main_location_long`	REAL,
	`main_location_lat`	REAL,
	`acknowledgements`	TEXT,
	`citation`	TEXT,
	`grants_used`	TEXT,
	`has_quota`	INTEGER,
	`i_am_owner`	INTEGER,
	`license_terms`	TEXT,
	`number_of_deployments`	INTEGER,
	`number_of_individuals`	INTEGER,
	`number_of_tags`	INTEGER,
	`study_objective`	TEXT,
	`study_type`	TEXT,
	`suspend_license_terms`	INTEGER,
	`i_can_see_data`	INTEGER,
	`there_are_data_which_i_cannot_see`	INTEGER,
	`timestamp_first_deployed_location`	TEXT,
	`timestamp_last_deployed_location`	TEXT,
	`number_of_deployed_locations`	INTEGER,
	`taxon_ids`	TEXT,
	`sensor_type_ids`	TEXT
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS `sensor` (
	`sensor_id`		INTEGER PRIMARY KEY,
	`sensor_type_id`	INTEGER,
	`tag_id`	INTEGER,
	
	FOREIGN KEY(tag_id) REFERENCES tag(tag_id)
) WITHOUT ROWID;

--DROP TABLE individual
CREATE TABLE IF NOT EXISTS `individual` (
	`individual_id`	INTEGER PRIMARY KEY,
	`local_identifier`	TEXT,
	`nick_name`	TEXT,
	`study_id`	REAL,
	`ring_id`	TEXT,
	`sex`	TEXT,
  `taxon_id`	INTEGER,
  `taxon_canonical_name`	TEXT,
	`access_profile_id`	INTEGER,
	`default_profile_eventdata_id`	INTEGER,
	`earliest_date_born`	TEXT,
	`latest_date_born`	TEXT,
	`exact_date_of_birth`	TEXT,
	`external_id`	INTEGER,
	`external_id_namespace_id`	INTEGER,
	`i_am_owner`	INTEGER,
	`death_comments`	TEXT,
	`comments`	TEXT,
	
	FOREIGN KEY(study_id) REFERENCES study(study_id)
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS `deployment` (
	`deployment_id`	INTEGER PRIMARY KEY,
	`local_identifier`	TEXT,
	`individual_id`	INTEGER,
	`tag_id`	INTEGER,
	`deploy_on_timestamp`	TEXT,
	`deploy_off_timestamp`	TEXT,
	
	FOREIGN KEY(tag_id) REFERENCES tag(tag_id),
	FOREIGN KEY(individual_id) REFERENCES individual(individual_id)
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS `event` (
	`event_id`	INTEGER PRIMARY KEY,
	`study_id` REAL,
	`individual_id`	INTEGER,
	`lon`	REAL,
	`lat`	REAL,
	`timestamp`	TEXT,
	`tag_id`	INTEGER,
	`sensor_type_id`	INTEGER,
	`ground_speed`	REAL,
	`gps_speed_accuracy_estimate` REAL,
  `gps_dop` REAL,
  `gps_hdop` REAL, 
  `gps_vdop` REAL, 
  `gps_satellite_count` REAL,
  `horizontal_accuracy` REAL,
  `time_to_fix` REAL,
  `fix_type` INTEGER,
	FOREIGN KEY(tag_id) REFERENCES tag(tag_id),
	FOREIGN KEY(study_id) REFERENCES study(study_id),
	FOREIGN KEY(individual_id) REFERENCES individual(individual_id)
) WITHOUT ROWID;


---- Create Indices

-- event table
--TODO: revisit these indices. sqlite will only use the first columns in the index
-- and will not use an index if the query does not use the first column
create index idx_event_timestamp on event (timestamp);
create index idx_event_individual_id on event (individual_id);
--TODO: I probably don't use the index below
-- maybe just have an index for event_id, to speed up joins
create index idx_event_full on event (event_id,individual_id,study_id,timestamp);
create index idx_event_studyid on event (study_id);

--individual table
--TODO: I probably don't use both individual_id and study_id together
-- could split into two indices
create index idx_individual on individual (individual_id,study_id);

COMMIT;
