/// <amd-module name='manage-agency'/>


import Vue from "vue";
import VueResource from "vue-resource";
// import Utils from "./utils";

Vue.use(VueResource);

interface State {
    initialised: boolean;
    failed: boolean;
    agency?: Agency;
}

interface Agency {
    label: string;
    locations: any[];
}

Vue.component('manage-agency', {
    template: `
<div v-if="initialised">
  <div class="col s12 m9 l10">
    <h2>{{this.agency.label}}</h2>

    <section id="locations" class="scrollspy section">
      <div class="card">
        <div class="card-content">
          <button class="btn right">Add new location</button>

          <h4>Locations</h4>

          <div class="card" v-for="location in this.agency.locations">
            <div class="card-content">
              <button class="btn btn-small right">Add user to location</button>
              <h5>{{location.location.name}}</h5>
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
                      <button class="btn btn-small right">Edit</button>
                    </td>
                  </tr>
                </tbody>
              </table>
              <div v-else>
                <p>No members for this location</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section id="users" class="scrollspy section">
      <div class="card">
        <div class="card-content">
          <h4>Users</h4>

          <table>
            <thead>
              <tr>
                <th>Username</th>
                <th>Name</th>
                <th>Role(s)</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="user in this.mergedUsers">
                <td>{{user.username}}</td>
                <td>{{user.name}}</td>
                <td>
                  <ul>
                    <li v-for="role in user.roles">{{role}}</li>
                  </ul>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>

    <pre>{{this.agency}}</pre>
  </div>
  <div class="col hide-on-small-only m3 l2">
    <ul class="section table-of-contents">
      <li><a href="#locations">Locations</a></li>
      <li><a href="#users">Users</a></li>
    </ul>
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
            agency: undefined,
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
    computed: {
        mergedUsers: function(): object[] {
            const usernames: string[] = [];
            const users: any = {};

            if (!this.agency) {
                return [];
            }

            for (const location of this.agency.locations) {
                for (const member of location.members) {
                    if (!users[member.username]) {
                        usernames.push(member.username);
                        users[member.username] = {
                            username: member.username,
                            name: member.name,
                            roles: [],
                        }
                    }

                    // \u2014 = emdash
                    users[member.username].roles.push(location.location.name + " \u2014 " + member.role);
                }
            }

            let result: any = [];
            usernames.sort();

            for (const username of usernames) {
                result.push(users[username]);
            }

            return result;
        }
    },
    mounted: function () {
        this.refreshAgency();
    }
});
