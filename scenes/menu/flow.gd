class_name Flow
extends RefCounted

## Lead the player through the screens (see section 6 of DESIGN.md): from the
## intro, Play goes on through the language (the first time), the creator of
## the rider and her horse (the first time), the instruction (the first time)
## and the request for room around her (once each start, with the camera on)
## to the next level, and the end of a level to the reward; Levels opens the
## level select, How to Play the instruction, and Settings the settings, where
## the language and the rider can be changed.

const INTRO := "res://scenes/intro/intro.tscn"
const LANGUAGE_SELECT := "res://scenes/language_select/language_select.tscn"
const RIDER_CREATOR := "res://scenes/rider_creator/rider_creator.tscn"
const INSTRUCTION := "res://scenes/instruction/instruction.tscn"
const LEVEL_SELECT := "res://scenes/level_select/level_select.tscn"
const SETTINGS := "res://scenes/settings/settings.tscn"
const LEVEL := "res://scenes/level/level.tscn"
const REWARD := "res://scenes/reward/reward.tscn"
const FREE_SPACE := "res://scenes/free_space/free_space.tscn"

## Whether the player is on her way from Play to the level (else she opened a
## screen from a menu, and goes back to it when done).
static var playing := false

## The screen to go back to from a screen opened in a menu.
static var back := INTRO

## The path of the level to play (see [LevelList]); empty for the next one.
static var level := ""

## Whether the player was asked for room around her since the game started.
static var room_asked := false

## The stars won in the level just finished, for the reward.
static var reward_stars := 0


## Go on from the end of a level with the stars to the reward.
static func reward(tree: SceneTree, stars: int) -> void:
    reward_stars = stars
    open(tree, REWARD)


## Go on from Play to the first screen which is still missing, or the level.
## Play goes to the next level which is not finished yet, or to the level
## select when all are.
static func play(tree: SceneTree, path := "") -> void:
    playing = true
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
    elif not profile.has_rider:
        tree.change_scene_to_file.call_deferred(RIDER_CREATOR)
    elif not profile.has_seen_instruction:
        tree.change_scene_to_file.call_deferred(INSTRUCTION)
    elif not room_asked and tree.root.get_node("Vision").service.GetStatus() != "Disabled":
        tree.change_scene_to_file.call_deferred(FREE_SPACE)
    else:
        playing = false
        if level == "":
            level = LevelList.next(profile)
        if level == "":
            back = INTRO
            tree.change_scene_to_file.call_deferred(LEVEL_SELECT)
        else:
            tree.change_scene_to_file.call_deferred(LEVEL)


## Open a screen from a menu, which goes back to [param from] when done.
static func open(tree: SceneTree, path: String, from := INTRO) -> void:
    playing = false
    back = from
    tree.change_scene_to_file.call_deferred(path)


## Leave the screen without finishing it (e.g., with Escape): back to the
## screen which opened it, or to the intro on the way from Play.
static func cancel(tree: SceneTree) -> void:
    open(tree, INTRO if playing else back, INTRO)
