/// <amd-module name='manage-agency'/>


import Vue from "vue";
import VueResource from "vue-resource";
// import Utils from "./utils";

Vue.use(VueResource);

interface State {
    initialised: boolean;
    failed: boolean;
    agency: Agency;
}

interface Agency {
    label: string;
}

Vue.component('manage-agency', {
    template: `
<div v-if="initialised">
  <div class="col s8">
    <h2>Editing {{this.agency.label}}</h2>

    <button class="btn right">Add new location</button>

    <template v-for="location in this.agency.locations">
      <h4>{{location.location.name}}</h4>
      <button class="btn btn-small">Add user to location</button>
      <table class="highlight" v-if="location.members.length > 0">
        <thead>
          <th>Username</th>
          <th>Name</th>
          <th>Role</th>
          <th>Permissions</th>
          <th></th>
        </thead>
        <tbody>
          <tr v-for="member in location.members">
            <td>{{member.username}}</td>
            <td>{{member.name}}</td>
            <td>{{member.role}}</td>
            <td>
              <ul>
                <li v-for="permission in member.permissions">
                  {{permission}}
                </li>
              </ul>
            </td>
            <td>
              <button class="btn btn-small">Edit</button>
            </td>
          </tr>
        </tbody>
      </table>
      <div class="card" v-else>
        <div class="card-content">No members for this location</div>
      </div>
    </template>

    <pre>{{this.agency}}</pre>
  </div>
</div>
<div v-else-if="failed">
<p>Could not fetch the agency you requested</p>
</div>

`,
  data: function(): State {
        return {
            initialised: false,
            failed: false,
            agency: {
                label: "test",
            },
        };
    },
    props: {
        agency_ref: String
    },
    methods: {
        refreshAgency: function() {
            this.$http.get(`/agencies/${this.agency_ref}/json`, {
                method: 'GET',
                params: {
                },
            }).then((response: any) => {
                return response.json();
            }, () => {
                // Failed
                this.failed = true;
            }).then((json: any) => {
                if (!this.failed) {
                    this.initialised = true;
                    this.agency = json;
                }
            })
        }
    },
    mounted: function () {
        this.refreshAgency();
    }
});
