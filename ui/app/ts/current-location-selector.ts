import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);
import Utils from "./utils";

interface location {
    id: number,
    name: string,
    agency_id: number,
    agency_label: string,
}

interface agency {
    id: number,
    label: string,
}

Vue.component('current-location-selector', {
    template: `
<div>
    <template v-if="available.length == 1">
        <div style="display: inline-block;">
            {{ current_location.agency_label }} -- {{ current_location.name }}
        </div>
    </template>
    <template v-if="available.length > 1">
        <div style="display: inline-block; width: 200px;">
            <select class="browser-default" v-model="selected_agency_id" v-on:change="refresh()">
                <option v-for="agency in agencyOptions()" v-bind:value="agency.id">{{ agency.label }}</option>
            </select>
        </div>
        <div style="display: inline-block; width: 200px;">
            <select class="browser-default" v-model="selected_location_id">
                <option v-for="location in locationOptions()" v-bind:value="location.id">{{ location.name }}</option>
            </select>
        </div>
        <div style="display: inline-block; width: 80px;">
            <button class="waves-effect waves-light btn-small" v-on:click="updateCurrentLocation()">Go</button>
        </div>
    </template>
</div>
`,
    data: function ():
        {
	    current_location: location,
            selected_location_id: number,
            selected_agency_id: number,
            available: location[],
        }
    {
        return {
            current_location: JSON.parse(this.current_location),
            selected_location_id: JSON.parse(this.current_location).id,
            selected_agency_id: JSON.parse(this.current_agency).id,
            available: JSON.parse(this.available_locations),
        }
    },
    props: ['current_agency', 'current_location', 'available_locations', 'csrf_token'],
    methods: {
        agencyOptions: function() {
            var agencies:agency[] = [];

            this.available.forEach(function (location:location) {
                let agency:agency = {id: location.agency_id, label: location.agency_label};

                if (!Utils.find(agencies, (a)=>{return a.id == agency.id})) {
                    agencies.push(agency);
                }
            });

            return agencies;
        },

        locationOptions: function() {
            var locations:location[] = [];

            for (let location of this.available) {
                if (location.agency_id == this.selected_agency_id) {
                    locations.push(location);
                }
            };

            return locations;
        },

        refresh:function() {
            Vue.set(this, 'selected_location_id', this.locationOptions()[0].id);
            this.$forceUpdate();
        },

        updateCurrentLocation: function() {
            this.$http.post('/set-location',
            {
                agency_id: this.selected_agency_id,
                location_id: this.selected_location_id,
                authenticity_token: this.csrf_token,
            },
            {
                emulateJSON: true
            }).then(() => {
                location.reload();
            }, () => {
                console.log("FAILED TO SET LOCATION");
            });
        },
    }
});