/datum/round_event_control/anomaly
	name = "Anomaly: Energetic Flux"
	typepath = /datum/round_event/anomaly

	min_players = 1
	max_occurrences = 0 //This one probably shouldn't occur! It'd work, but it wouldn't be very fun.
	weight = 15
	category = EVENT_CATEGORY_ANOMALIES
	description = "This anomaly shocks and explodes. This is the base type."

/datum/round_event/anomaly
	var/area/impact_area
	var/obj/effect/anomaly/anomaly_path = /obj/effect/anomaly/flux
	announceWhen = 1


/datum/round_event/anomaly/proc/findEventArea()
	var/static/list/allowed_areas
	if(!allowed_areas)
		//Places that shouldn't explode
		var/static/list/safe_area_types = typecacheof(list(
		/area/station/ai_monitored/turret_protected/ai,
		/area/station/ai_monitored/turret_protected/ai_upload,
		/area/station/engineering,
		/area/station/solars,
		/area/station/holodeck,
		/area/shuttle,
		/area/station/maintenance,
		/area/icemoon,
	))

		//Subtypes from the above that actually should explode.
		var/static/list/unsafe_area_subtypes = typecacheof(list(/area/station/engineering/break_room))

		allowed_areas = make_associative(GLOB.the_station_areas) - safe_area_types + unsafe_area_subtypes
	var/list/possible_areas = typecache_filter_list(GLOB.sortedAreas,allowed_areas)
	if (length(possible_areas))
		return pick(possible_areas)

/datum/round_event/anomaly/setup()
	impact_area = findEventArea()
	if(!impact_area)
		CRASH("No valid areas for anomaly found.")
	var/list/turf_test = (get_area_turfs(impact_area) - typesof(/turf/open/lava))
	if(!turf_test.len)
		CRASH("Anomaly : No valid turfs found for [impact_area] - [impact_area.type]")

/datum/round_event/anomaly/announce(fake)
	priority_announce("Localized energetic flux wave detected on long range scanners. Expected location of impact: [impact_area.name].", "Anomaly Alert")

/datum/round_event/anomaly/start()
	var/turf/T = pick((get_area_turfs(impact_area) - typesof(/turf/open/lava)))
	var/newAnomaly
	if(T)
		newAnomaly = new anomaly_path(T)
	if (newAnomaly)
		announce_to_ghosts(newAnomaly)
