/// <amd-module name='controlled-records-download'/>

import Vue from "vue";
import VueResource from "vue-resource";

Vue.use(VueResource);

declare var M: any;

Vue.component('controlled-records-download', {
    template: `
<span>
    <a class="btn btn-small right blue" @click.prevent.default="show()">Download CSV</a>
    <div ref="modal" class="modal">
        <div class="modal-content">
            <h3>Download CSV</h3>
            <p>You are about to generate a CSV report for ~{{approximate_count}} records.</p>
            <p>This may take a few moments.</p>
            <p>Click Download CSV to proceed</p>
        </div> 
        <div class="modal-footer">
            <a href="#!" class="modal-close waves-effect waves-green btn-flat">Close</a>
            <a v-if="!confirmed" class="btn waves-effect blue" target="_blank" :href="url" v-on:click="confirm()">Download CSV</a>
            <a v-if="confirmed" href="#!" class="btn green modal-close waves-effect">Done</a>
        </div>
    </div>
</span>
`,
    data: function(): {confirmed: boolean} {
        return {
            confirmed: false,
        };
    },
    props: ['approximate_count', 'url'],
    methods: {
        show: function() {
            const modal: any = M.Modal.init(this.$refs.modal, {
                onCloseEnd: () => {
                    this.confirmed = false;
                }
            });
            modal.open();
        },
        confirm() {
            setTimeout(() => {
                this.confirmed = true;
            }, 2000);
        },
    },
});
