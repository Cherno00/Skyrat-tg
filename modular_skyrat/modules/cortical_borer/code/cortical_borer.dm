GLOBAL_VAR_INIT(objective_egg_borer_number, 2)
GLOBAL_VAR_INIT(objective_egg_egg_number, 5)
GLOBAL_VAR_INIT(objective_willing_hosts, 2)
GLOBAL_VAR_INIT(objective_blood_chem, 3)
GLOBAL_VAR_INIT(objective_blood_borer, 3)

GLOBAL_VAR_INIT(successful_egg_number, 0)
GLOBAL_LIST_EMPTY(willing_hosts)
GLOBAL_VAR_INIT(successful_blood_chem, 0)

GLOBAL_LIST_EMPTY(cortical_borers)

//we need a way of buffing leg speed
/datum/movespeed_modifier/borer_speed
	multiplicative_slowdown = -0.4

/datum/actionspeed_modifier/borer_speed
	multiplicative_slowdown = -0.3
	id = ACTIONSPEED_ID_BORER

//so that we know if a mob has a borer (only humans should have one, but in case)
/mob/proc/has_borer()
	for(var/check_content in contents)
		if(iscorticalborer(check_content))
			return check_content
	return FALSE

//so if a person is debrained, the borer is removed
/obj/item/organ/internal/brain/Remove(mob/living/carbon/target, special = 0, no_id_transfer = FALSE)
	. = ..()
	var/mob/living/simple_animal/cortical_borer/cb_inside = target.has_borer()
	if(cb_inside)
		cb_inside.leave_host()

//borers also create an organ, so you dont need to debrain someone
/obj/item/organ/internal/borer_body
	name = "engorged cortical borer"
	desc = "the body of a cortical borer, full of human viscera, blood, and more."
	zone = BODY_ZONE_HEAD
	/// Ref to the borer who this organ belongs to
	var/mob/living/simple_animal/cortical_borer/borer

/obj/item/organ/internal/borer_body/Destroy()
	borer = null
	return ..()

/obj/item/organ/internal/borer_body/Insert(mob/living/carbon/carbon_target, special, drop_if_replaced)
	. = ..()
	for(var/datum/borer_focus/body_focus as anything in borer.body_focuses)
		body_focus.on_add()
	carbon_target.hal_screwyhud = SCREWYHUD_HEALTHY

//on removal, force the borer out
/obj/item/organ/internal/borer_body/Remove(mob/living/carbon/carbon_target, special)
	. = ..()
	var/mob/living/simple_animal/cortical_borer/cb_inside = carbon_target.has_borer()
	for(var/datum/borer_focus/body_focus as anything in cb_inside.body_focuses)
		body_focus.on_remove()
	if(cb_inside)
		cb_inside.leave_host()
	carbon_target.hal_screwyhud = SCREWYHUD_NONE
	qdel(src)

/obj/item/reagent_containers/borer
	volume = 100

/mob/living/simple_animal/cortical_borer
	name = "cortical borer"
	desc = "A slimy creature that is known to go into the ear canal of unsuspecting victims."
	icon = 'modular_skyrat/modules/cortical_borer/icons/animal.dmi'
	icon_state = "brainslug"
	icon_living = "brainslug"
	icon_dead = "brainslug_dead"
	maxHealth = 25
	health = 25
	//they need to be able to pass tables and mobs
	pass_flags = PASSTABLE | PASSMOB
	//they are below mobs, or below tables
	layer = BELOW_MOB_LAYER
	//corticals are tiny
	mob_size = MOB_SIZE_TINY
	//because they are small, why can't they be held?
	can_be_held = TRUE
	///what chemicals borers know, starting with none
	var/list/known_chemicals = list()
	///what chemicals the borer can learn
	var/list/potential_chemicals = list(/datum/reagent/medicine/spaceacillin,
										/datum/reagent/medicine/potass_iodide,
										/datum/reagent/medicine/diphenhydramine,
										/datum/reagent/medicine/epinephrine,
										/datum/reagent/medicine/haloperidol,
										/datum/reagent/toxin/formaldehyde,
										/datum/reagent/impurity/libitoil,
										/datum/reagent/impurity/mannitol,
										/datum/reagent/medicine/c2/libital,
										/datum/reagent/medicine/c2/lenturi,
										/datum/reagent/medicine/c2/convermol,
										/datum/reagent/medicine/c2/seiver,
										/datum/reagent/medicine/c2/multiver,
										/datum/reagent/lithium,
										/datum/reagent/medicine/salglu_solution,
										/datum/reagent/medicine/mutadone,
										/datum/reagent/toxin/heparin,
										/datum/reagent/drug/methamphetamine/borer_version,
										/datum/reagent/medicine/morphine,
										/datum/reagent/medicine/inacusiate,
										/datum/reagent/medicine/oculine,
										/datum/reagent/toxin/mindbreaker,
	)
	//blacklisted chemicals - separate from chemicals that cannot be synthesized, borers specifically cannot learn these
	var/list/blacklisted_chemicals = list(/datum/reagent/medicine/mannitol,
										/datum/reagent/medicine/neurine,
	)
	///how old the borer is, starting from zero. Goes up only when inside a host
	var/maturity_age = 0
	///the amount of "evolution" points a borer has for chemicals. Start with one
	var/chemical_evolution = 1
	///the amount of "evolution" points a borer has for stats
	var/stat_evolution = 0
	///how many chemical points the borer can have. Can be upgraded
	var/max_chemical_storage = 50
	///how many chemical points the borer has
	var/chemical_storage = 50
	///how fast chemicals are gained. Goes up only when inside a host
	var/chemical_regen = 1
	///the list of actions that the borer has
	var/list/known_abilities = list(/datum/action/cooldown/borer/toggle_hiding,
									/datum/action/cooldown/borer/choosing_host,
									/datum/action/cooldown/borer/inject_chemical,
									/datum/action/cooldown/borer/upgrade_chemical,
									/datum/action/cooldown/borer/learn_focus,
									/datum/action/cooldown/borer/upgrade_stat,
									/datum/action/cooldown/borer/learn_ability,
									/datum/action/cooldown/borer/force_speak,
									/datum/action/cooldown/borer/fear_human,
									/datum/action/cooldown/borer/check_blood,
	)
	///the list of actions that the borer could learn
	var/possible_abilities = list(/datum/action/cooldown/borer/produce_offspring,
								/datum/action/cooldown/borer/learn_bloodchemical,
								/datum/action/cooldown/borer/revive_host,
								/datum/action/cooldown/borer/willing_host,
	)
	///the host
	var/mob/living/carbon/human/human_host
	//what the host gains or loses with the borer
	var/list/hosts_abilities = list()
	//just a little "timer" to compare to world.time
	var/timed_maturity = 0
	///multiplies the current health up to the max health
	var/health_regen = 1.02
	//holds the chems right before injection
	var/obj/item/reagent_containers/reagent_holder
	//just a flavor kind of thing
	var/generation = 1
	/// List of focus datums
	var/list/possible_focuses = list()
	/// What focuses the borer has unlocked
	var/list/body_focuses = list()
	///how many children the borer has produced
	var/children_produced = 0
	///how many blood chems have been learned through the blood
	var/blood_chems_learned = 0
	///we dont want to spam the chat
	var/deathgasp_once = FALSE
	//the limit to the chemical and stat evolution
	var/limited_borer = 10
	///borers can only enter biologicals if true
	var/organic_restricted = TRUE
	///borers are unable to enter changelings if true
	var/changeling_restricted = TRUE
	/// Assoc list of chemical injection rates that the borer can have
	var/static/list/injection_rates = list(
		5,
		10,
		25,
		50,
	)
	/// Which injection rates the borer has unlocked
	var/list/injection_rates_unlocked = list(
		5,
	)
	/// What is the current injection rate of the borer
	var/injection_rate_current = 5
	/// Cooldown between injecting chemicals
	COOLDOWN_DECLARE(injection_cooldown)

/mob/living/simple_animal/cortical_borer/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT) //they need to be able to move around
	name = "[initial(name)] ([generation]-[rand(100,999)])" //so their gen and a random. ex 1-288 is first gen named 288, 4-483 if fourth gen named 483
	if(prob(5))
		var/switching = rand(1,2)
		switch(switching)
			if(1)
				name = "cortical boner ([generation]-[rand(100,999)])"
			if(2)
				name = "cortical vorer ([generation]-[rand(100,999)])"
	GLOB.cortical_borers += src
	reagent_holder = new /obj/item/reagent_containers/borer(src)
	for(var/action_type in known_abilities)
		var/datum/action/attack_action = new action_type()
		attack_action.Grant(src)
	if(mind)
		if(!mind.has_antag_datum(/datum/antagonist/cortical_borer))
			mind.add_antag_datum(/datum/antagonist/cortical_borer)
	for(var/focus_path in subtypesof(/datum/borer_focus))
		possible_focuses += new focus_path

/mob/living/simple_animal/cortical_borer/Destroy()
	human_host = null
	GLOB.cortical_borers -= src
	if(mind)
		mind.remove_all_antag_datums()
	QDEL_NULL(reagent_holder)
	return ..()

/mob/living/simple_animal/cortical_borer/death(gibbed)
	if(inside_human())
		var/turf/human_turf = get_turf(human_host)
		forceMove(human_turf)
		human_host = null
	GLOB.cortical_borers -= src
	if(!deathgasp_once)
		deathgasp_once = TRUE
		for(var/borers in GLOB.cortical_borers)
			to_chat(borers, span_boldwarning("[src] has left the hivemind forcibly!"))
	if(mind)
		mind.remove_all_antag_datums()
	QDEL_NULL(reagent_holder)
	return ..()

//so we can add some stuff to status, making it easier to read... maybe some hud some day
/mob/living/simple_animal/cortical_borer/get_status_tab_items()
	. = ..()
	. += "Chemical Storage: [chemical_storage]/[max_chemical_storage]"
	. += "Chemical Evolution Points: [chemical_evolution]"
	. += "Stat Evolution Points: [stat_evolution]"
	. += ""
	if(host_sugar())
		. += "Sugar detected! Unable to generate resources!"
		. += ""
	. += "OBJECTIVES:"
	. += "1) [GLOB.objective_egg_borer_number] borers producing [GLOB.objective_egg_egg_number] eggs: [GLOB.successful_egg_number]/[GLOB.objective_egg_borer_number]"
	. += "2) [GLOB.objective_willing_hosts] willing hosts: [length(GLOB.willing_hosts)]/[GLOB.objective_willing_hosts]"
	. += "3) [GLOB.objective_blood_borer] borers learning [GLOB.objective_blood_chem] from the blood: [GLOB.successful_blood_chem]/[GLOB.objective_blood_borer]"

/mob/living/simple_animal/cortical_borer/Life(delta_time, times_fired)
	. = ..()
	//can only do stuff when we are inside a LIVING human
	if(!inside_human() || human_host?.stat == DEAD)
		return

	//there needs to be a negative to having a borer
	if(prob(5) && human_host.getToxLoss() <= 80)
		human_host.adjustToxLoss(5, TRUE, TRUE)

	if(human_host.hal_screwyhud != SCREWYHUD_HEALTHY)
		human_host.hal_screwyhud = SCREWYHUD_HEALTHY

	//cant do anything if the host has sugar
	if(host_sugar())
		if(!has_status_effect(/datum/status_effect/borer_sugar))
			apply_status_effect(/datum/status_effect/borer_sugar)
	else
		if(has_status_effect(/datum/status_effect/borer_sugar))
			remove_status_effect(/datum/status_effect/borer_sugar)

	//this is regenerating chemical_storage
	if(chemical_storage < max_chemical_storage)
		chemical_storage = min(chemical_storage + chemical_regen, max_chemical_storage)
		if(chemical_storage > max_chemical_storage)
			chemical_storage = max_chemical_storage

	//this is regenerating health
	if(health < maxHealth)
		health = min(health * health_regen, maxHealth)
		if(health > maxHealth)
			health = maxHealth

	//this is so they can evolve
	if(timed_maturity < world.time)
		timed_maturity = world.time + 1 SECONDS
		maturity_age++

		//20:40, 15:30, 10:20, 5:10
		var/maturity_threshold = 20
		if(GLOB.successful_egg_number >= GLOB.objective_egg_borer_number)
			maturity_threshold -= 2
		if(length(GLOB.willing_hosts) >= GLOB.objective_willing_hosts)
			maturity_threshold -= 10
		if(GLOB.successful_blood_chem >= GLOB.objective_blood_borer)
			maturity_threshold -= 3

		if(maturity_age == maturity_threshold)
			if(chemical_evolution < limited_borer) //you can only have a default of 10 at a time
				chemical_evolution++
				to_chat(src, span_notice("You gain a chemical evolution point. Spend it to learn a new chemical!"))
			else
				to_chat(src, span_warning("You were unable to gain a chemical evolution point due to having the max!"))
		if(maturity_age >= (maturity_threshold * 2))
			if(stat_evolution < limited_borer)
				stat_evolution++
				to_chat(src, span_notice("You gain a stat evolution point. Spend it to become stronger!"))
			else
				to_chat(src, span_warning("You were unable to gain a stat evolution point due to having the max!"))
			maturity_age = 0

//if it doesnt have a ckey, let ghosts have it
/mob/living/simple_animal/cortical_borer/attack_ghost(mob/dead/observer/user)
	. = ..()
	if(ckey || key)
		return
	if(stat == DEAD)
		return
	var/choice = tgui_input_list(usr, "Do you want to control [src]?", "Confirmation", list("Yes", "No"))
	if(choice != "Yes")
		return
	if(ckey || key)
		return
	to_chat(user, span_warning("As a borer, you have the option to be friendly or not. Note that how you act will determine how a host responds!"))
	to_chat(user, span_warning("You are a cortical borer! You can fear someone to make them stop moving, but make sure to inhabit them! You only grow/heal/talk when inside a host!"))
	ckey = user.ckey
	if(mind)
		mind.add_antag_datum(/datum/antagonist/cortical_borer)

//check if we are inside a human
/mob/living/simple_animal/cortical_borer/proc/inside_human()
	if(!ishuman(loc))
		return FALSE
	return TRUE

//check if the host has sugar
/mob/living/simple_animal/cortical_borer/proc/host_sugar()
	if(human_host?.reagents?.has_reagent(/datum/reagent/consumable/sugar))
		return TRUE
	return FALSE

//leave the host, forced or not
/mob/living/simple_animal/cortical_borer/proc/leave_host()
	if(!human_host)
		return
	var/obj/item/organ/internal/borer_body/borer_organ = locate() in human_host.internal_organs
	if(borer_organ)
		borer_organ.Remove(human_host)
	var/turf/human_turf = get_turf(human_host)
	forceMove(human_turf)
	human_host = null

//borers shouldnt be able to whisper...
/mob/living/simple_animal/cortical_borer/whisper(message, bubble_type, list/spans, sanitize, datum/language/language, ignore_spam, forced, filterproof)
	to_chat(src, span_warning("You are not able to whisper!"))
	return FALSE

//previously had borers unable to emote... but that means less RP, and we want that

//borers should not be talking without a host at least
/mob/living/simple_animal/cortical_borer/say(message, bubble_type, list/spans, sanitize, datum/language/language, ignore_spam, forced)
	if(!inside_human())
		to_chat(src, span_warning("You are not able to speak without a host!"))
		return
	if(host_sugar())
		message = scramble_message_replace_chars(message, 10)
	message = sanitize(message)
	var/list/split_message = splittext(message, "")

	//this is so they can talk in hivemind
	if(split_message[1] == ";")
		message = copytext(message, 2)
		for(var/borer in GLOB.cortical_borers)
			to_chat(borer, span_purple("<b>Cortical Hivemind: [src] sings, \"[message]\"</b>"))
		for(var/mob/dead_mob in GLOB.dead_mob_list)
			var/link = FOLLOW_LINK(dead_mob, src)
			to_chat(dead_mob, span_purple("[link] <b>Cortical Hivemind: [src] sings, \"[message]\"</b>"))
		var/logging_textone = "[key_name(src)] spoke into the hivemind: [message]"
		log_say(logging_textone)
		return

	//this is when they speak normally
	to_chat(human_host, span_purple("Cortical Link: [src] sings, \"[message]\""))
	var/logging_texttwo = "[key_name(src)] spoke to [key_name(human_host)]: [message]"
	log_say(logging_texttwo)
	to_chat(src, span_purple("Cortical Link: [src] sings, \"[message]\""))
	for(var/mob/dead_mob in GLOB.dead_mob_list)
		var/link = FOLLOW_LINK(dead_mob, src)
		to_chat(dead_mob, span_purple("[link] Cortical Hivemind: [src] sings to [human_host], \"[message]\""))

//borers should not be able to pull anything
/mob/living/simple_animal/cortical_borer/start_pulling(atom/movable/AM, state, force, supress_message)
	to_chat(src, span_warning("You cannot pull things!"))
	return
