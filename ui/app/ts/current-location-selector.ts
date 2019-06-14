/// <amd-module name='current-location-selector'/>


import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);
import UI from "./ui";
import Utils from "./utils";

declare var M: any; // Materialize on the window context

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
<span>
    <template v-if="available.length == 1">
        <span class="current-location-display">
            <span class="current-location-display-agency" v-bind:title="current_location.agency_label">{{ current_location.agency_label }}</span>
            <span class="current-location-display-location" v-bind:title="current_location.name">{{ current_location.name }}</span>
        </span>
    </template>
    <template v-else>
        <a href="#" @click="showModal()">
            <span class="current-location-display">
                <span class="current-location-display-agency" v-bind:title="current_location.agency_label">{{ current_location.agency_label }}</span>
                <span class="current-location-display-location" v-bind:title="current_location.name">{{ current_location.name }}</span>
            </span>
        </a>
        <div ref="modal" class="modal">
            <div class="modal-content">
                <div>
                    <i class="fa fa-university left" style="line-height: 44px;margin: 0;width:20px;" aria-hidden="true"></i>
                    <select class="browser-default" v-model.number="selected_agency_id" style="width: calc(100% - 20px);" aria-label="Select Agency">
                        <option v-for="agency in agencyOptions" v-bind:value="agency.id">{{ agency.label }}</option>
                    </select>
                </div>
                <div class="clearfix"></div>
                <div>
                    <i class="fa fa-map-marker-alt left" style="line-height: 44px;margin: 0;width:20px;" aria-hidden="true"></i>
                    <select class="browser-default" v-model.number="selected_location_id" style="width: calc(100% - 20px);" aria-label="Select Agency Location">
                        <option v-for="location in locationOptions" v-bind:value="location.id">{{ location.name }}</option>
                    </select>
                </div>
            </div>
            <div class="modal-footer">
                <a href="#!" class="modal-close waves-effect waves-green btn-flat">Close</a>
                <button class="waves-effect waves-green btn-flat" v-on:click="updateCurrentLocation()">Change Agency/Location</button>
            </div>
        </div>
    </template>
</span>
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
        showModal: function() {
            const modal: any = M.Modal.init(this.$refs.modal, {
            });
            document.body.appendChild(this.$refs.modal as Element);
            modal.open();
        },
    },
});
