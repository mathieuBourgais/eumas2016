/**
* Name: evacuationsocial
* Author: Mathieu Bourgais
* Description: Modèle servant d'exemple à l'utilisation du moteur social. Faire un système d'attaque terroriste. Il y a des victimes, 1 terroriste et 1 flic. Quand les gens vont voir le terroriste, ils vont fuir
* tout en ayant un lien social dynamique avec. Une fois les victimes à l'aris, un flic va venir les chercher. Un lien social dynamique se crée et il va pouvoir intervenir pour savoir
* à quel moment les gens vont suivre le flic pour sortir.
* Tags: social
*/

model evacuationsocial

global {
	//Shapefile of the walls
	file wall_shapefile <- shape_file("../includes/walls.shp");
	//Shapefile of the exit
	file exit_shapefile <- shape_file("../includes/exit.shp");
	
	file point2_shapefile <- shape_file("../includes/point2.shp");
	//DImension of the grid agent
	int nb_cols <- 50;
	int nb_rows <- 50;
	
	//Shape of the world initialized as the bounding box around the walls
	geometry shape <- envelope(wall_shapefile);
	
	init {
		create safePlace from: point2_shapefile;
		
		//Creation of the wall and initialization of the cell is_wall attribute
		create wall from: wall_shapefile {
			ask cell overlapping self {
				is_wall <- true;
			}
		}
		//Creation of the exit and initialization of the cell is_exit attribute
		create exit from: exit_shapefile {
			ask (cell overlapping self) where not each.is_wall{
				is_exit <- true;
			}
		}
		
		create policeman number:1;
		create victim number: 2;
	}
	
	reflex stop_sim when:(empty(victim)){
		do pause;
	}
}
//Grid species to discretize space
grid cell width: nb_cols height: nb_rows neighbors: 8 {
	bool is_wall <- false;
	bool is_exit <- false;
	rgb color <- #white;	
}
//Species exit which represent the exit
species exit {
	aspect default {
		draw shape color: #blue;
	}
}
//Species which represent the wall
species wall {
	aspect default {
		draw shape color: #black /*depth: 10*/;
	}
}

species safePlace{
	
}

species people skills: [moving] control: simple_bdi{
	point target;
	rgb color <- #blue;
	float speed <-1.0;
	geometry perceived_area <- circle(20);
	
	//Reflex to move the agent 
	action deplacement {
		//Make the agent move only on cell without walls
		do goto target: target speed: 1 on: (cell where not each.is_wall) recompute_path: false;
	}
	
//	reflex update_perception {
//		//the agent perceived a cone (with an amplitude of 60°) at a distance of  perception_distance (the intersection with the world shape is just to limit the perception to the world)
//		perceived_area <- circle(20); 
//		
//		//if the perceived area is not nil, we use the masked_by operator to compute the visible area from the perceived area according to the obstacles
//		if (perceived_area != nil) {
//			perceived_area <- perceived_area masked_by (wall);
//		}
//	}
	
	aspect default {
		draw square(1) color: color;
	}
	aspect perception {
		if (perceived_area != nil) {
			draw perceived_area color: #green;
		}
	}
}

species victim parent: people{
	
	bool use_emotions_architecture <- true;
	bool use_social_architecture <- true;
	
	emotion fear <- new_emotion("fear");
	
	social_link social_link_policeman <- new_social_link(first(policeman));
	
	init{
		location <- one_of(safePlace).location;
		do add_emotion(fear);
		do add_desire(new_predicate("flee") with_priority 1.0);
		do add_desire(new_predicate("live",true) with_priority 0.0);
		do add_desire(new_predicate("hide") with_priority 2.0);
	}
	
	perceive target:policeman in:10{
		socialize dominance:-1.0;
		focus name:policeman;
	}
	
	perceive target:victim in:10{
		socialize;
	}
	
	rule belief:new_predicate("policeman") 
		remove_intention:new_predicate("hide") 
		remove_desire:new_predicate("hide") ;	
//		when:has_social_link(social_link_policeman set_solidarity 1.0);
		
	
	plan goExit intention:new_predicate("flee") 
	when:has_social_link(social_link_policeman set_solidarity 1.0){
		target <- first(exit).location;
		color <- #red;
		do deplacement;
		if (self distance_to target) < 2.0 {
			do die;
		}
	}
	
	plan hide intention:new_predicate("hide"){
		target <- first(safePlace).location;
		color <- #blue;
		do deplacement;
	}
}

species policeman parent:people{
	init{
		color <- #green;
		location <- first(exit).location;
		do add_desire(new_predicate("point2") with_priority 2.0);
		do add_desire(new_predicate("live",true) with_priority 0.0);
	}
	
	perceive target:victim in:5{
		focus name:victim;
	}
	
	rule belief:new_predicate("victim") new_desire:new_predicate("fuir") remove_intention:new_predicate("point2") remove_desire:new_predicate("point2");
	
	plan savePeople intention:new_predicate("point2") finished_when:has_desire(new_predicate("fuir")){
		target <- first(safePlace).location;
		do deplacement;
	}
	
	plan fuir intention:new_predicate("fuir"){
		target <- first(exit).location;
		do deplacement;		
	}
}

experiment evacuationsocial type: gui {
	output {
		display map type: opengl{
			image "../images/floor.jpg";
			species wall refresh: false;
			species exit refresh: false;
			species victim aspect: default;
			species policeman;
			
		}
	}
}
