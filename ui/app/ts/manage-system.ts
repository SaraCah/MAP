/// <amd-module name='manage-system'/>


import Vue from "vue";
import VueResource from "vue-resource";
import UI from "./ui";
// import Utils from "./utils";


Vue.use(VueResource);

interface State {
    initialised: boolean;
    failed: boolean;
    administrators?: Administrator[];
}

interface Administrator {
    username: string;
    name: string;
    inactive: string;
}


Vue.component('manage-system', {
    template: `
<div>
  <div class="row">
    <div class="col s12 m9 l10">
      <section id="administrators" class="scrollspy section">
        <div class="card">
          <div class="card-content">
            <button @click.prevent.default="addAdmin()" class="btn right">Add new administrator</button>

            <h4>Administrators</h4>

            <table>
              <thead>
                <tr>
                  <th>Username</th>
                  <th>Name</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="admin in administrators" :class="admin.is_inactive ? 'grey-text' : ''">
                  <td>{{admin.username}}</td>
                  <td>{{admin.name}}</td>
                  <td>
                    <button class="btn btn-small right" @click.prevent.default="editUser(admin.username)">Edit User</button>
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
        <li><a href="#administrators">Administrators</a></li>
      </ul>
    </div>
  </div>
</div>
`,
    data: function(): State {
        return {
            initialised: false,
            failed: false,
            administrators: undefined,
        };
    },
    methods: {
        refresh: function() {
            this.$http.get(`/system/json`, {
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
                    this.administrators = json.administrators;
                }
            });
        },
        addAdmin: function() {
            this.ajaxFormModal('/users/new-admin', {
                successCallback: () => {
                    this.refresh();
                },
            });
        },
        ajaxFormModal: function (url: string, opts: any) {
            this.$http.get(url, {
                method: 'GET',
                params: opts.params || {},
            }).then((response: any) => {
                const modalAndContentObj = UI.genericHTMLModal(response.body, ['manage-agency-modal']);

                const modal = modalAndContentObj[0];
                const contentPane = modalAndContentObj[1];

                setTimeout(function () {
                    new AjaxForm(contentPane, () => {
                        modal.close();

                        if (opts.successCallback) {
                            opts.successCallback();
                        }
                    });
                });
            }, () => {
                // failed
            });

        },
        editUser: function(username: string) {
            this.ajaxFormModal('/users/edit', {
                params: {
                    username: username,
                },
                successCallback: () => {
                    this.refresh();
                },
            });
        }
    },
    mounted: function() {
        this.refresh();
    },
});

