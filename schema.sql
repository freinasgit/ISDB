-------------------------------------------------------------------------
-------------------------------------------------------------------------
-- Translation to SQL and Integrity Constraints
-------------------------------------------------------------------------
-------------------------------------------------------------------------
-- Drop previously existing tables (if any)
-------------------------------------------------------------------------
drop table if exists trip cascade;
drop table if exists authorised cascade;
drop table if exists reservation cascade;
drop table if exists boat cascade;
drop table if exists date_interval cascade;
drop table if exists valid_for cascade;
drop table if exists sailing_certificate cascade;
drop table if exists boat_class cascade;
drop table if exists location cascade;
drop table if exists junior cascade;
drop table if exists senior cascade;
drop table if exists sailor cascade;
drop table if exists country cascade;
--------------------------------------------------------------------------
-- Create tables according to the Entity-Association diagram
--------------------------------------------------------------------------
-- Table Country
--------------------------------------------------------------------------
create table country(
   country_name   varchar(70),
   iso_code       char(2),
   country_flag   varchar(2083) not null,
   constraint pk_country_name primary key(country_name),
   constraint uniq_isocd_country unique(iso_code),
   constraint chk_isocd_country check(length(iso_code) = 2),
   constraint chk_flag_country check(length(country_flag) > 10));
---------------------------------------------------------------------------------
-- Table Sailor
---------------------------------------------------------------------------------
create table sailor(
   sailor_email        varchar(254),
   sailor_first_name   varchar(30) not null,
   sailor_surname      varchar(60) not null,
   constraint pk_email_sailor primary key(sailor_email),
   constraint chk_email_sailor check(length(sailor_email) > 5)
   -- Mandatory constraint: Every sailor must exist either in table 'senior' or in table 'junior'.
   -- Disjoint constraint: Any sailor cannot exist in tables 'senior' and 'junior' at the same time.
 );
--------------------------------------------------------------------------------------------------
-- Table Senior
--------------------------------------------------------------------------------------------------
create table senior(
   senior_email        varchar(254),
   senior_first_name   varchar(30),
   senior_surname      varchar(60),
   constraint pk_email_senior primary key(senior_email),
   constraint fk_email_senior foreign key(senior_email)
      references sailor(sailor_email)
);
--------------------------------------------------------------------------------------------------
-- Table Junior
--------------------------------------------------------------------------------------------------
create table junior(
   junior_email        varchar(254),
   junior_first_name   varchar(30),
   junior_surname      varchar(60),
   constraint pk_email_junior primary key(junior_email),
   constraint fk_email_junior foreign key(junior_email)
       references sailor(sailor_email)
);
-------------------------------------------------------------------------------------------------------------------------------------
-- Table Location
-------------------------------------------------------------------------------------------------------------------------------------
create table location(
   authority_of    varchar(70),
   latitude        numeric(8,6),
   longitude       numeric(9,6),
   location_name   varchar(70) not null,
   constraint pk_location primary key(latitude, longitude),
   constraint fk_authority_of_location foreign key(authority_of) references country(country_name)
   -- IC2: Any two locations must be at least one nautical mile apart (the distance between two
   -- locations depends on their latitudes and longitudes).
);
-------------------------------------------------------------------------------------------------------------------------------------
-- Table Boat Class
-------------------------------------------------------------------------------------------------------------------------------------
create table boat_class(
   class_name   char(6),
   max_length   smallint,
   constraint pk_name_boat_class primary key(class_name),
   constraint chk_max_length_min_value check(not(max_length < 6)),
   constraint chk_max_length_max_value check(not(max_length > 100))
);
-------------------------------------------------------------------------------------------------------------------------------------
-- Table Sailing Certificate
-------------------------------------------------------------------------------------------------------------------------------------
create table sailing_certificate(
   sailor_email        varchar(254),
   for_class_name      char(6),
   issue_date          date,
   expiry_date         date,
   constraint pk_sailing_certificate primary key(sailor_email, issue_date, expiry_date),
   constraint fk_sailor_email_sailing_certificate foreign key(sailor_email) 
      references sailor(sailor_email),
   constraint fk_class_name_sailing_certificate foreign key(for_class_name) 
      references boat_class(class_name),
   constraint chk_issue_expiry_dates_boat check(issue_date < expiry_date),
   constraint chk_length_boat check(length between 6 and 100)
   -- Mandatory constraint: Every sailing certificate must exist in table 'valid_for'.
);
-------------------------------------------------------------------------------------------------------------------------------------
-- Table Valid For
-------------------------------------------------------------------------------------------------------------------------------------
create table valid_for(
   country_name   varchar(70),
   sailor_email   varchar(254),
   issue_date     date,
   expiry_date    date,
   constraint pk_valid_for primary key(country_name, sailor_email, issue_date, expiry_date),
   constraint fk_country_name_valid_for foreign key(country_name) 
      references country(country_name),
   constraint fk_sailing_certificate_valid_for foreign key(sailor_email, issue_date, expiry_date) 
      references sailing_certificate(sailor_email, issue_date, expiry_date)
);
-----------------------------------------------------------------------------------------------------
-- Table Boat
-----------------------------------------------------------------------------------------------------
create table boat(
   country_registration   varchar(70),
   cni                    char(17),
   boat_name              varchar(33) not null,
   length                 smallint not null,
   year_registration      smallint not null,
   class_name             char(6),
   constraint pk_boat primary key(country_registration, cni),
   constraint fk_country_registration_boat foreign key(country_registration)
       references country(country_name),
   constraint fk_class_name_boat foreign key(class_name)
       references boat_class(class_name),
   constraint chk_cni_boat check(cni like '__-________-__-__'),
   constraint chk_year_registration_boat
       check(year_registration between (extract(year from current_date) - 100) and (extract(year from current_date))),
   constraint chk_length_boat check(length between 6 and 100)
   -- Length of boat is measured in feet.
   -- Year of registration of boat cannot exceed 100 years, since current year.
   -- IC1: The country of registration of a boat must have at least one maritime location in table 'location'.
);
--------------------------------------------------------------------------------------
-- Table Date Interval
--------------------------------------------------------------------------------------
create table date_interval(
   start_date   date,
   end_date     date,
   constraint pk_date_interval primary key(start_date, end_date),
   constraint chk_start_end_dates_schedule check(end_date > start_date),
   constraint chk_start_date_schedule check(start_date > current_date),
   constraint chk_max_date_interval check(end_date - start_date + 1 <= 183)
);
-----------------------------------------------------------------------------------------
-- Table Reservation
-----------------------------------------------------------------------------------------
create table reservation(
   boat_country_reg   varchar(70),
   cni                char(17),
   start_date         date,
   end_date           date,
   responsible        varchar(254),
   constraint pk_reservation primary key(boat_country_reg, cni, start_date, end_date),
   constraint fk_boat_reservation foreign key(boat_country_reg, cni)
       references boat(country_registration, cni),
   constraint fk_start_end_dates_reservation foreign key(start_date, end_date)
       references date_interval(start_date, end_date),
   constraint fk_responsible_reservation foreign key(responsible)
       references senior(senior_email)
   -- IC: Reservation schedules of a boat must not overlap.
   -- Mandatory constraint: Every reservation must exist in table 'authorised'.
   -- IC6: The responsible of reservation must exist in table 'authorised'.
);
-----------------------------------------------------------------------------------------
-- Table Authorised
-----------------------------------------------------------------------------------------
create table authorised(
   boat_country_reg   varchar(70),
   cni                char(17),
   sailor_email       varchar(254),
   start_date         date,
   end_date           date,
   constraint pk_authorised primary key(boat_country_reg, cni, sailor_email, start_date, end_date),
   constraint fk_reservation_authorised foreign key(boat_country_reg, cni, start_date, end_date)
       references reservation(boat_country_reg, cni, start_date, end_date),
   constraint fk_sailor_authorised foreign key(sailor_email)
       references sailor(sailor_email)
);
-----------------------------------------------------------------------------------------------------------------------------
-- Table Trip
-----------------------------------------------------------------------------------------------------------------------------
create table trip(
   boat_country_reg   varchar(70),
   cni                char(17),
   start_date         date,
   end_date           date,
   take_off_date      date,
   arrival_date       date,
   insurance          char(10) not null,
   from_latitude      numeric(8,6),
   from_longitude     numeric(9,6),
   to_latitude        numeric(8,6),
   to_longitude       numeric(9,6),
   skipper            varchar(254),
   constraint pk_trip primary key(boat_country_reg, cni, start_date, end_date, take_off_date, arrival_date),
   constraint fk_reservation_trip foreign key(boat_country_reg, cni, start_date, end_date)
         references reservation(boat_country_reg, cni, start_date, end_date),
   constraint fk_from_trip foreign key(from_latitude, from_longitude)
       references location(latitude, longitude),
   constraint fk_to_trip foreign key(to_latitude, to_longitude)
       references location(latitude, longitude),
   constraint fk_skipper_trip foreign key(skipper)
       references authorised(sailor_email),
   constraint chk_take_off_arrival_dates_trip check(take_off_date < arrival_date),
   constraint chk_take_off_date_trip check((start_date <= take_off_date) and (take_off_date < end_date)),
   constraint chk_arrival_date_trip check(arrival_date <= end_date),
   constraint chk_duration_trip check(take_off_date - arrival_date between 1 and 91)
   -- IC: Trips of a reservation must not overlap. This restriction only applies for reservations with more than one trip.
   -- IC3: The skipper must exist in table 'authorised' for the corresponding reservation.
);
-----------------------------------------------------------------------------------------------------------------------------------
--END
-----------------------------------------------------------------------------------------------------------------------------------