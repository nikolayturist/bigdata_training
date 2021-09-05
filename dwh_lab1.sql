create sequence dim_date_pk_seq start with 1 increment by 1;

-- drop table dim_date
create table dim_date (
    id number primary key,
    date_full date,
    year number(4),
    month number(2),
    day number(2),
    day_of_week number(1),
    day_of_month number(2),
    day_of_year number(3),
    day_string varchar2(50),
    date_string varchar2 (100)
);

create unique index date_full_uindx on dim_date(date_full);
create unique index ymd_uindx on dim_date(year, month, day);

insert into dim_date (id, date_full, year, month, day, day_of_week, day_of_month, day_of_year, day_string, date_string)
select 
    dim_date_pk_seq.nextval id,   
    to_date(dy.yy || '0101', 'YYYYMMDD') + d.dd date_full,
    dy.yy as year,
    to_number(to_char(to_date(dy.yy || '0101', 'YYYYMMDD') + d.dd, 'MM')) as month,   
    to_number(to_char(to_date(dy.yy || '0101', 'YYYYMMDD') + d.dd, 'DD')) day,
    to_number(to_char(to_date(dy.yy || '0101', 'YYYYMMDD') + d.dd, 'D')) day_of_week,
    to_number(to_char(to_date(dy.yy || '0101', 'YYYYMMDD') + d.dd, 'DD')) day_of_month, 
    to_number(to_char(to_date(dy.yy || '0101', 'YYYYMMDD') + d.dd, 'DDD')) day_of_year, 
    to_char(to_date(dy.yy || '0101', 'YYYYMMDD') + d.dd, 'Day') day_string,
    to_char(to_date(dy.yy || '0101', 'YYYYMMDD') + d.dd, 'DD Month YYYY') date_string
from dual,
    (select 2015 as yy from dual) dy, 
    (select level-1 dd from dual connect by level <= 365) d;
    
commit;

--------------------------------------------------------------------------------

create sequence dim_time_seq_pk start with 1 increment by 1;

create table dim_time (
    id number primary key,
    time_short varchar2(10),
    time_long varchar2(10),
    time_hour varchar2(2),
    time_minute varchar2(2),
    time_am_pm varchar2(2)    
);

create unique index dim_time_short_indx on dim_time(time_short);

insert into dim_time (id, time_short, time_long, time_hour, time_minute, time_am_pm)
select 
    dim_time_seq_pk.nextval id,
    to_char(dd + mm, 'HH24MI') as time_short,
    to_char(dd + mm, 'HH24:MI') as time_long,
    to_char(dd + mm, 'HH24') as time_hour,
    to_char(dd + mm, 'MI') as time_minute,
    to_char(dd + mm, 'AM') as time_am_pm
from 
    (select to_date('20100101 00:00:00', 'YYYYMMDD HH24:MI:SS') dd from dual) d, 
    (select (level - 1) / 1440 mm from dual connect by level <= 1440) m;
    
commit;    
--------------------------------------------------------------------------------
-- slowly changing dimention: name of airline can be changed (and it can be closed)
create sequence dim_airline_seq_pk start with 1 increment by 1;

-- drop table dim_airlines;
create table dim_airlines (
    id number primary key,
    airline_id number, 
    iata_code varchar2(26),
    AIRLINE	VARCHAR2(128),
    airline_start_date date default to_date('20100101' , 'YYYYMMDD'),
    airline_end_date date
);

create index dim_airlines_iata_indx on dim_airlines(iata_code, airline_start_date);

insert into dim_airlines (id, airline_id,  iata_code, AIRLINE) 
select 
    dim_airline_seq_pk.nextval,
    id airline_id, 
    iata_code, AIRLINE from demo.airlines;

commit;
--------------------------------------------------------------------------------
-- slowly changing dimention: name of airport can be changed (and it can be closed)    
create sequence dim_airport_seq_pk start with 1 increment by 1;

-- drop table dim_airports;
create table dim_airports (
    id number primary key,
    airport_id number,
    iata_code varchar2(26 byte), 
	airport varchar2(500 byte), 
	city varchar2(500 byte), 
	state varchar2(500 byte), 
	country varchar2(26 byte), 
	latitude number(38,5), 
	longitude number(38,5),
    airport_start_date date default to_date('20100101' , 'YYYYMMDD'),
    airport_end_date date
);

create index dim_airport_iata_indx on dim_airports(iata_code, airport_start_date);

insert into dim_airports (id, airport_id, iata_code, airport, city, state, country, latitude, longitude) 
select dim_airport_seq_pk.nextval id, id as airport_id, iata_code, airport, city, state, country, latitude, longitude from demo.airports;

commit;
--------------------------------------------------------------------------------

create table fact_flights (
    id number primary key,    
    flight_date_id number not null references dim_date(id),
    airline_id number not null references dim_airlines(id),
    flight_number number,
    tail_number varchar2(50),
    orig_airport_id number references dim_airports(id),
    dest_airport_id number references dim_airports(id),
    -- 
    sched_dep_date_id number references dim_date(id),
    sched_dep_time_id number references dim_time(id),
    -- 
    dep_date_id number references dim_date(id),
    dep_time_id number references dim_time(id),
    --
    departure_delay number,
    taxi_out number,
    -- 
    wheels_off_date_id number references dim_date(id),
    wheels_off_time_id number references dim_time(id),
    --
    scheduled_time number,
    elapsed_time number,
    air_time number,
    distance number,
    --
    wheels_on_date_id number references dim_date(id),
    wheels_on_time_id number references dim_time(id),
    
    taxi_in number,
    --
    shed_arrival_date_id number references dim_date(id),
    shed_arrival_time_id number references dim_time(id),
    -- 
    arrival_date_id number references dim_date(id),
    arrival_time_id number references dim_time(id),
    --    
    arrival_delay number,
    diverted number,
    cancelled number,
    cancellation_reason varchar2(1),
    cancellation_reason_desc varchar2(1000),
    air_system_delay number,
    SECURITY_DELAY	number,
    AIRLINE_DELAY	number,
    LATE_AIRCRAFT_DELAY	number,
    WEATHER_DELAY	number    
);

create table fact_delay_stats (
    id number primary key,
    flight_date_id number not null references dim_date(id),
    airline_id number not null references dim_airlines(id),
    orig_airport_id number references dim_airports(id),
    dest_airport_id number references dim_airports(id),
    total_SECURITY_DELAY	number,
    total_AIRLINE_DELAY	number,
    total_LATE_AIRCRAFT_DELAY	number,
    total_WEATHER_DELAY	number   ,
    avg_SECURITY_DELAY	number,
    avg_AIRLINE_DELAY	number,
    avg_LATE_AIRCRAFT_DELAY	number,
    avg_WEATHER_DELAY	number ,
    min_SECURITY_DELAY	number,
    min_AIRLINE_DELAY	number,
    min_LATE_AIRCRAFT_DELAY	number,
    min_WEATHER_DELAY	number ,
    max_SECURITY_DELAY	number,
    max_AIRLINE_DELAY	number,
    max_LATE_AIRCRAFT_DELAY	number,
    max_WEATHER_DELAY	number
);


create table fact_cancellation_stat(
    id number primary key,
    flight_date_id number not null references dim_date(id),
    airline_id number not null references dim_airlines(id),
    orig_airport_id number references dim_airports(id),
    cancellation_reason_code varchar2(1),
    cancellation_reason_count number
);