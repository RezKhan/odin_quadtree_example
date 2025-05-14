package game

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:strings"
import "core:mem"

window_width :: 1280
window_height :: 720
qtree_capacity :: 1

Entity :: struct {
    position: rl.Vector2,
    color: rl.Color,
    number: int,
}

BoundingBox :: struct {
    center: rl.Vector2,
    width: f32,
    height: f32,
}

QuadTree :: struct {
    bounds: BoundingBox,
    capacity: int,
    divided: bool,
    entities: [dynamic]Entity,
    name: string,

    topLeft: ^QuadTree,
    topRight: ^QuadTree,
    bottomLeft: ^QuadTree,
    bottomRight: ^QuadTree,
}

init_entity:: proc(i: int) -> Entity {
    entity := Entity{}

    entity.position.x = f32(rl.GetRandomValue(0, window_width))
    entity.position.y = f32(rl.GetRandomValue(0, window_height))
    entity.color = {220, 127, 127, 255}
    entity.number = i

    return entity
}

init_root_quadtree :: proc(bounds: BoundingBox) -> QuadTree {
    qtree := QuadTree{}
    qtree.bounds = bounds
    qtree.capacity = qtree_capacity
    qtree.divided = false
    qtree.name = "root"

    divide_quadtree(&qtree)

    return qtree
}

divide_quadtree :: proc(qtree: ^QuadTree) {
    qtree.divided = true
    x := qtree.bounds.center.x
    y := qtree.bounds.center.y
    
    half_width := qtree.bounds.width / 2
    half_height := qtree.bounds.height / 2

    qtree.topLeft = new(QuadTree)
    qtree.topLeft.bounds.center = {x - half_width / 2, y - half_height / 2}
    // qtree.topLeft.name = strings.concatenate({qtree.name, "_topLeft"})

    qtree.topRight = new(QuadTree)
    qtree.topRight.bounds.center = {x + half_width / 2, y - half_height / 2}
    // qtree.topRight.name = strings.concatenate({qtree.name, "_topRight"})
    
    qtree.bottomLeft = new(QuadTree)
    qtree.bottomLeft.bounds.center = {x - half_width / 2, y + half_height / 2}
    // qtree.bottomLeft.name = strings.concatenate({qtree.name, "_bottomLeft"})
    
    qtree.bottomRight = new(QuadTree)
    qtree.bottomRight.bounds.center = {x + half_width / 2, y + half_height / 2}
    // qtree.bottomRight.name = strings.concatenate({qtree.name, "_bottomRight"})
    
    qtree_children := [4]^QuadTree{qtree.topLeft, qtree.topRight, 
        qtree.bottomLeft, qtree.bottomRight}

    for child in qtree_children {
        child.bounds.width = half_width
        child.bounds.height = half_height
        child.capacity = qtree_capacity
        child.divided = false
    }
}

quadtree_entity_insert :: proc(entity: Entity, qtree: ^QuadTree) {
    if !bound_contains(qtree.bounds, entity.position) {
        return
    }
    if len(qtree.entities) < qtree.capacity && check_quadtree_entities(qtree) {
        append(&qtree.entities, entity)
    } else {
        if !qtree.divided {
            divide_quadtree(qtree)
        }
        qtree_children := [4]^QuadTree{qtree.topLeft, qtree.topRight, 
        qtree.bottomLeft, qtree.bottomRight}
        
        for i in 0..<len(qtree.entities) {
            for child in qtree_children {
                quadtree_entity_insert(qtree.entities[i], child)
            }
            ordered_remove(&qtree.entities, i)
        }
        // resize_dynamic_array(&qtree.entities, 0)
        qtree.entities = nil

        for child in qtree_children {
            quadtree_entity_insert(entity, child)
        }
    }
}

check_quadtree_entities :: proc(qtree: ^QuadTree) -> bool {
    if !qtree.divided {
        return true
    } else {
        if qtree.topLeft.entities != nil || qtree.topRight.entities != nil ||
        qtree.bottomLeft.entities != nil || qtree.bottomRight.entities != nil  {
            return false
        } 
    }
    return false
}

bound_contains :: proc(bounds: BoundingBox, point: rl.Vector2) -> bool {
    return  (point.x >= bounds.center.x - bounds.width / 2) && 
            (point.x <= bounds.center.x + bounds.width / 2) && 
            (point.y >= bounds.center.y - bounds.height / 2) && 
            (point.y <= bounds.center.y + bounds.height / 2)
}

draw_quadtree :: proc(qtree: ^QuadTree) {
    if len(qtree.entities) < 1 {
        rl.DrawRectangleLines(i32(qtree.bounds.center.x - (qtree.bounds.width / 2)), 
            i32(qtree.bounds.center.y - (qtree.bounds.height / 2)), 
            i32(qtree.bounds.width), i32(qtree.bounds.height), {255, 255, 255, 45})
    } else {
        rl.DrawRectangleLines(i32(qtree.bounds.center.x - (qtree.bounds.width / 2)), 
        i32(qtree.bounds.center.y - (qtree.bounds.height / 2)), 
        i32(qtree.bounds.width), i32(qtree.bounds.height), {248, 180, 0, 255})
    }

    if qtree.divided {
        draw_quadtree(qtree.topLeft) 
        draw_quadtree(qtree.topRight)
        draw_quadtree(qtree.bottomLeft)
        draw_quadtree(qtree.bottomRight)
    }
}

free_quadtree :: proc(qtree: ^QuadTree) {
    if qtree == nil {
        return
    }
    if qtree.divided {
        free_quadtree(qtree.topLeft)
        free_quadtree(qtree.topRight)
        free_quadtree(qtree.bottomLeft)
        free_quadtree(qtree.bottomRight)
    }  else {
        delete_dynamic_array(qtree.entities)
    }
    if qtree.name == "root" {
        // root takes extra handling
        qtree.topLeft = nil
        qtree.topRight = nil
        qtree.bottomLeft = nil
        qtree.bottomRight = nil
        free(qtree.topLeft)
        free(qtree.topRight)
        free(qtree.bottomLeft)
        free(qtree.bottomRight)

        return
    }
    free(qtree)
}

print_quadtree :: proc(qtree: ^QuadTree) {
    fmt.println("Quadtree:", qtree.name, "Divided: ", qtree.divided, "Entities: ", qtree.entities)
    if qtree.divided {
        print_quadtree(qtree.topLeft)
        print_quadtree(qtree.topRight)
        print_quadtree(qtree.bottomLeft)
        print_quadtree(qtree.bottomRight)
    }
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

    rl.InitWindow(window_width, window_height, "Quadtree Example")
    rl.SetExitKey(.ESCAPE)
    rl.SetTargetFPS(60)
 
    prime_bbox := BoundingBox{}
    prime_bbox.center = {window_width / 2, window_height / 2}
    prime_bbox.width = f32(window_width)
    prime_bbox.height = f32(window_height)
    
    entity_count := 50
    entity_array : [dynamic]Entity
    tick := 0
    qtree := init_root_quadtree(prime_bbox)
    for i in 0..<entity_count {
        entity := init_entity(i)
        append(&entity_array, entity)
        quadtree_entity_insert(entity, &qtree)
    }
    set_clear := false

    for !rl.WindowShouldClose() {
        tick += 1
        if tick == 60 {
            for entity in entity_array {
                quadtree_entity_insert(entity, &qtree)
            }
            tick = 0
        }
        rl.BeginDrawing()
        rl.ClearBackground({22, 22, 22, 255})

        for i in 0..<len(entity_array) {
            rl.DrawCircleV(entity_array[i].position, 2, entity_array[i].color)
        }
        draw_quadtree(&qtree)
        if tick == 59 {
            set_clear = true
        }

        rl.EndDrawing()
        if set_clear {
            free_quadtree(&qtree)
            divide_quadtree(&qtree)
            set_clear = false
        }
    }
    rl.CloseWindow()

    free_quadtree(&qtree)
    print_quadtree(&qtree)
}