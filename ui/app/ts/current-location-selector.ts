/// <amd-module name='current-location-selector'/>


import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);
import UI from "./ui";
import Utils from "./utils";

interface Location {
    id: number;
    name: string;
    agency_id: number;
    agency_label: string;
}

interface Agency {
    id: number;
    label: string;
}

interface SelectorState {
    current_location: Location;
    selected_location_id: number;
    selected_agency_id: number;
    available: Location[];
}

Vue.component('current-location-selector', {
    template: `
<div>
    <template v-if="available.length == 1">
        <div style="line-height: 48px;padding-right: 10px;">
            {{ current_location.agency_label }} -- {{ current_location.name }}
        </div>
    </template>
    <template v-else>
        <div style="display: inline-block; width: 200px;">
            <select class="browser-default" v-model.number="selected_agency_id">
                <option v-for="agency in agencyOptions" v-bind:value="agency.id">{{ agency.label }}</option>
            </select>
        </div>
        <div style="display: inline-block; width: 200px;">
            <select class="browser-default" v-model.number="selected_location_id">
                <option v-for="location in locationOptions" v-bind:value="location.id">{{ location.name }}</option>
            </select>
        </div>
        <div style="display: inline-block; width: 80px;">
            <button class="waves-effect waves-light btn-small" v-on:click="updateCurrentLocation()">Go</button>
        </div>
    </template>
</div>
`,
    data: function(): SelectorState {
        const currentLocation = JSON.parse(this.current_location_json);
        const currentAgency = JSON.parse(this.current_agency_json);
        const availableLocations = JSON.parse(this.available_locations_json);

        return {
            current_location: currentLocation,
            selected_location_id: Number(currentLocation.id),
            selected_agency_id: Number(currentAgency.id),
            available: availableLocations,
        };
    },
    props: ['current_agency_json', 'current_location_json', 'available_locations_json', 'csrf_token'],
    computed: {
        agencyOptions: function() {
            const agencies: Agency[] = [];

            this.available.forEach(function(location: Location) {
                const agency: Agency = {id: location.agency_id, label: location.agency_label};

                if (!Utils.find(agencies, (a) => a.id === agency.id)) {
                    agencies.push(agency);
                }
            });

            return agencies;
        },

        locationOptions: function() {
            // Recomputed on page load & when the user changes agencies.
            const locations: Location[] = [];

            for (const location of this.available) {
                if (location.agency_id === this.selected_agency_id) {
                    locations.push(location);
                }
            }

            if (!Utils.find(locations, (location: Location) => location.id === this.selected_location_id)) {
                this.selected_location_id = locations[0].id;
            }

            return locations;
        },
    },
    methods: {
        updateCurrentLocation: function() {
            this.$http.post('/set-location', {
                agency_id: this.selected_agency_id,
                location_id: this.selected_location_id,
                authenticity_token: this.csrf_token,
            }, {
                emulateJSON: true,
            }).then(() => {
                location.reload();
            }, () => {
                UI.genericModal("Error: Failed to set your location");
            });
        },
    },
});
