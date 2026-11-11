@tool
class_name Creek
extends River

## Place a narrow creek in a level, flowing from the west to the east across
## the whole steppe at the height of this node, without a ford: the horse
## crosses it only by jumping over it (see [method Rider.jump]), and the jump
## must carry it across. A jump from a stand or a walk falls short, and the
## horse is back on the bank it jumped from; from a trot or a gallop, it flies
## over. The horse drinks on its banks, as at a river.
##
## Its blocking circles are apart from the others (see
## [method LevelMap.jumpable]), so that a horse in the air flies over them.
