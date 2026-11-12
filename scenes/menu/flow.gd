class_name Flow
extends RefCounted

## Lead the player through the screens (see section 6 of DESIGN.md): from the
## intro, Play goes on through the language (the first time), the journeys
## (once each start; a new journey is named first, then the players choose
## whether one or two ride), the creator of the rider and her horse (once for
## each player of the journey), the instruction (the first time)
## and the request for room around her (once each start, with the camera on)
## to the next level, and the end of a level to the reward; Levels goes on
## through the journeys (once each start) and the creator to the level select,
## so that it shows the progress of the journey they ride in, How to Play opens
## the instruction, and Settings the settings, where the language and the
## journey can be changed.
##
## A level is played only in a journey where it is open: a level chosen before
## the journey (e.g., in the level select of another journey) leads to the
## level select of the chosen journey instead.

const INTRO := "res://scenes/intro/intro.tscn"
const LANGUAGE_SELECT := "res://scenes/language_select/language_select.tscn"
const RIDER_CREATOR := "res://scenes/rider_creator/rider_creator.tscn"
const INSTRUCTION := "res://scenes/instruction/instruction.tscn"
const LEVEL_SELECT := "res://scenes/level_select/level_select.tscn"
const SETTINGS := "res://scenes/settings/settings.tscn"
const LEVEL := "res://scenes/level/level.tscn"
const REWARD := "res://scenes/reward/reward.tscn"
const FREE_SPACE := "res://scenes/free_space/free_space.tscn"
const WARDROBE := "res://scenes/wardrobe/wardrobe.tscn"
const SESSIONS := "res://scenes/sessions/sessions.tscn"
const SESSION_NAME := "res://scenes/session_name/session_name.tscn"
const PLAYER_COUNT := "res://scenes/player_count/player_count.tscn"

## Whether the player is on her way from Play to the level (else she opened a
## screen from a menu, and goes back to it when done).
static var playing := false

## The screen to go back to from a screen opened in a menu.
static var back := INTRO

## The path of the level to play (see [LevelList]); empty for the next one.
static var level := ""

## Whether the player is on her way from Levels to the level select.
static var choosing := false

## Whether the players chose their journey since the game started.
static var session_asked := false

## Whether the player was asked for room around her since the game started.
static var room_asked := false

## The stars won in the level just finished, for the reward.
static var reward_stars := 0

## The id of the level just finished, for the reward; empty in the tests.
static var reward_level := ""

## The player who chooses her gift now (see [Reward]): with two players, they
## choose one after the other.
static var reward_player := 0

## The player whose wardrobe opens (see [Wardrobe]).
static var wardrobe_player := 0


## Go on from the end of a level with the stars to the reward.
static func reward(tree: SceneTree, stars: int, level_id := "") -> void:
    reward_stars = stars
    reward_level = level_id
    reward_player = 0
    open(tree, REWARD)


## Go on from Play to the first screen which is still missing, or the level.
## Play goes to the next level which is not finished yet, or to the level
## select when all are.
static func play(tree: SceneTree, path := "") -> void:
    playing = true
    choosing = false
    back = INTRO
    level = path
    next(tree)


## Go on to the next screen: the missing ones on the way to the level, or back
## to the screen which opened this one.
static func next(tree: SceneTree) -> void:
    if not playing:
        tree.change_scene_to_file.call_deferred(back)
        return
    var profile := tree.root.get_node("Profile")
    if not tree.root.get_node("Languages").has_chosen:
        tree.change_scene_to_file.call_deferred(LANGUAGE_SELECT)
    elif not session_asked or profile.session_id == "":
        if profile.sessions().is_empty():
            tree.change_scene_to_file.call_deferred(SESSION_NAME)
        else:
            tree.change_scene_to_file.call_deferred(SESSIONS)
    elif profile.players == 0:
        tree.change_scene_to_file.call_deferred(PLAYER_COUNT)
    elif not profile.has_riders():
        tree.change_scene_to_file.call_deferred(RIDER_CREATOR)
    elif choosing:
        playing = false
        choosing = false
        back = INTRO
        tree.change_scene_to_file.call_deferred(LEVEL_SELECT)
    elif not profile.has_seen_instruction:
        tree.change_scene_to_file.call_deferred(INSTRUCTION)
    elif not room_asked and tree.root.get_node("Vision").service.GetStatus() != "Disabled":
        tree.change_scene_to_file.call_deferred(FREE_SPACE)
    else:
        playing = false
        if level != "" and not LevelList.is_open(level, profile):
            level = ""
            back = INTRO
            tree.change_scene_to_file.call_deferred(LEVEL_SELECT)
            return
        if level == "":
            level = LevelList.next(profile)
        if level == "":
            back = INTRO
            tree.change_scene_to_file.call_deferred(LEVEL_SELECT)
        else:
            tree.change_scene_to_file.call_deferred(LEVEL)


## Go on from Levels to the level select of the journey they ride in: first
## the journeys (once each start) and the creator, if missing.
static func levels(tree: SceneTree) -> void:
    playing = true
    choosing = true
    back = INTRO
    level = ""
    next(tree)


## Open a screen from a menu, which goes back to [param from] when done.
static func open(tree: SceneTree, path: String, from := INTRO) -> void:
    playing = false
    choosing = false
    back = from
    tree.change_scene_to_file.call_deferred(path)


## Leave the screen without finishing it (e.g., with Escape): back to the
## screen which opened it, or to the intro on the way from Play.
static func cancel(tree: SceneTree) -> void:
    open(tree, INTRO if playing else back, INTRO)
