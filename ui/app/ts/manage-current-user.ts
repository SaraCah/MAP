/// <amd-module name='manage-current-user'/>


import Vue from "vue";
import VueResource from "vue-resource";
import UI from "./ui";
// import Utils from "./utils";


Vue.use(VueResource);

Vue.component('manage-current-user', {
    template: `
<a href="#" @click.prevent.default="editUser()" class="white-text">Edit</a>
`,
    props: {
        username: String,
    },
    methods: {
        ajaxFormModal: function (url: string, opts: any) {
            this.$http.get(url, {
                method: 'GET',
                params: opts.params || {},
            }).then((response: any) => {
                UI.genericHTMLModal(response.body,
                                    ['manage-agency-modal'],
                                    {
                                        onReady: function (modal: any, contentPane: HTMLElement) {
                                            new AjaxForm(contentPane, () => {
                                                modal.close();

                                                if (opts.successCallback) {
                                                    opts.successCallback();
                                                }
                                            });
                                        }
                                    });
            }, () => {
                // failed
            });

        },
        editUser: function() {
            this.ajaxFormModal('/users/edit', {
                params: {
                    username: this.username,
                },
                successCallback: () => {
                    location.reload();
                },
            });
        }
    },
});

