.PRECIOUS: %.pbf
.SECONDARY: $(COUNTRIES_PBF)

$(shell mkdir -p world output filtered_ferry filtered_train filtered_bus world/europe)

# Common variables for train and ferry
WANTED_COUNTRIES := $(shell grep -v "\#" countries.wanted)
COUNTRIES_PBF := $(addsuffix -latest.osm.pbf,$(addprefix world/,$(WANTED_COUNTRIES)))

# New variables for bus
BUS_WANTED_COUNTRIES := $(shell grep -v "\#" bus_countries.wanted)
BUS_COUNTRIES_PBF := $(addsuffix -latest.osm.pbf,$(addprefix world/europe/,$(BUS_WANTED_COUNTRIES)))

# Download the raw source file of a country
world/%.osm.pbf:
	wget -N -q --show-progress -P world/ https://download.geofabrik.de/$*.osm.pbf

# Download the raw source file of a country for bus, specifying folder
world/europe/%.osm.pbf:
	wget -N -q --show-progress -P world/europe/ https://download.geofabrik.de/europe/$*.osm.pbf

# Filter a raw country (in world/*) to type-specific data (in filtered/*)
filtered_ferry/%.osm.pbf: world/%.osm.pbf params/ferry_filter.params
	mkdir -p filtered_ferry
	osmium tags-filter --expressions=params/ferry_filter.params $< -o $@ --overwrite

filtered_train/%.osm.pbf: world/%.osm.pbf params/train_filter.params
	mkdir -p filtered_train
	osmium tags-filter --expressions=params/train_filter.params $< -o $@ --overwrite
	
filtered_aerialway/%.osm.pbf: world/%.osm.pbf params/train_filter.params
	mkdir -p filtered_aerialway
	osmium tags-filter --expressions=params/aerialway_filter.params $< -o $@ --overwrite --progress -v

# Filter a raw country for bus (in world/europe/*) to type-specific data (in filtered_bus/*)
filtered_bus/%.osm.pbf: world/europe/%.osm.pbf params/bus_filter.params
	mkdir -p filtered_bus
	osmium tags-filter --expressions=params/bus_filter.params $< -o $@ --overwrite

# Combine all type-specific data (in filtered/*) into one file
output/filtered_ferry.osm.pbf: $(subst world,filtered_ferry,$(COUNTRIES_PBF))
	osmium merge $^ -o $@ --overwrite

output/filtered_train.osm.pbf: $(subst world,filtered_train,$(COUNTRIES_PBF))
	osmium merge $^ -o $@ --overwrite
	
output/filtered_aerialway.osm.pbf: $(subst world,filtered_aerialway,$(COUNTRIES_PBF))
	osmium merge $^ -o $@ --overwrite

# Combine all type-specific bus data into one file, using BUS_COUNTRIES_PBF variable
output/filtered_bus.osm.pbf: $(subst world/europe,filtered_bus,$(BUS_COUNTRIES_PBF))
	osmium merge $^ -o $@ --overwrite

# Compute the real OSRM data on the combined file
output/filtered_ferry.osrm: output/filtered_ferry.osm.pbf profiles/ferry.lua
	docker run --rm -t -v $(shell pwd):/opt/host osrm/osrm-backend:v5.22.0 osrm-extract -p /opt/host/profiles/ferry.lua /opt/host/$<
	docker run --rm -t -v $(shell pwd):/opt/host osrm/osrm-backend:v5.22.0 osrm-partition /opt/host/$<
	docker run --rm -t -v $(shell pwd):/opt/host osrm/osrm-backend:v5.22.0 osrm-customize /opt/host/$<

output/filtered_train.osrm: output/filtered_train.osm.pbf profiles/train.lua
	docker run --rm -t -v $(shell pwd):/opt/host osrm/osrm-backend:v5.22.0 osrm-extract -p /opt/host/profiles/train.lua /opt/host/$<
	docker run --rm -t -v $(shell pwd):/opt/host osrm/osrm-backend:v5.22.0 osrm-partition /opt/host/$<
	docker run --rm -t -v $(shell pwd):/opt/host osrm/osrm-backend:v5.22.0 osrm-customize /opt/host/$<
	
output/filtered_aerialway.osrm: output/filtered_aerialway.osm.pbf profiles/aerialway.lua
	docker run --rm -t -v $(shell pwd):/opt/host osrm/osrm-backend:v5.22.0 osrm-extract -p /opt/host/profiles/aerialway.lua /opt/host/$<
	docker run --rm -t -v $(shell pwd):/opt/host osrm/osrm-backend:v5.22.0 osrm-partition /opt/host/$<
	docker run --rm -t -v $(shell pwd):/opt/host osrm/osrm-backend:v5.22.0 osrm-customize /opt/host/$<

output/filtered_bus.osrm: output/filtered_bus.osm.pbf profiles/bus.lua
	docker run --rm -t -v $(shell pwd):/opt/host osrm/osrm-backend:v5.25.0 osrm-extract -p /opt/host/profiles/bus.lua /opt/host/$<
	docker run --rm -t -v $(shell pwd):/opt/host osrm/osrm-backend:v5.25.0 osrm-partition /opt/host/$<
	docker run --rm -t -v $(shell pwd):/opt/host osrm/osrm-backend:v5.25.0 osrm-customize /opt/host/$<

bus: output/filtered_bus.osrm

train: output/filtered_train.osrm

aerialway: output/filtered_aerialway.osrm

ferry: output/filtered_ferry.osrm

all: train ferry bus aerialway

serve-train: train
	-@docker stop train_routing > /dev/null 2>&1 && docker rm train_routing > /dev/null 2>&1
	docker run --restart always --name train_routing -t -d -p 5000:5000 -v $(shell pwd):/opt/host osrm/osrm-backend:v5.22.0 osrm-routed --algorithm mld /opt/host/output/filtered_train.osrm
	
serve-ferry: ferry
	-@docker stop ferry_routing > /dev/null 2>&1 && docker rm ferry_routing > /dev/null 2>&1
	docker run --restart always --name ferry_routing -t -d -p 5001:5000 -v $(shell pwd):/opt/host osrm/osrm-backend:v5.22.0 osrm-routed --algorithm mld /opt/host/output/filtered_ferry.osrm

serve-bus: bus
	-@docker stop bus_routing > /dev/null 2>&1 && docker rm bus_routing > /dev/null 2>&1
	docker run --restart always --memory=10g --memory-swap=10g --name bus_routing -t -d -p 5569:5000 -v $(shell pwd):/opt/host osrm/osrm-backend:v5.25.0 osrm-routed --algorithm mld /opt/host/output/filtered_bus.osrm

serve-aerialway: aerialway
	-@docker stop aerialway_routing > /dev/null 2>&1 && docker rm aerialway_routing > /dev/null 2>&1
	docker run --restart always --name aerialway_routing -t -d -p 5003:5000 -v $(shell pwd):/opt/host osrm/osrm-backend:v5.22.0 osrm-routed --algorithm mld /opt/host/output/filtered_aerialway.osrm

serve-all: serve-train serve-aerialway serve-ferry serve-bus
