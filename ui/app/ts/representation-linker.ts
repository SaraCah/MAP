/// <amd-module name='representation-linker'/>


import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";
// import Utils from "./utils";
// import UI from "./ui";
Vue.use(VueResource);

import Record from "./controlled-records";

interface Representation {
    id: string;
    label: string;
}

declare var M: any; // Materialize on the window context

export default class RepresentationRequest {
    public static fromRepresentation(rep: Representation): RepresentationRequest {
        return new RepresentationRequest(rep.id, rep.label, 'DIGITAL');
    }

    public recordDetails: string;
    public metadata: any;

    constructor(public id: string,
                public label: string,
                public requestType: string) {
        this.recordDetails = '';
    }

    public isDigitalRepresentation():boolean {
        return this.id.substring(0, 'digital_representation'.length) === 'digital_representation';
    }
}

Vue.component('representation-browse', {
    template: `
<div>
    <a href="javascript:void(0);" class="btn right" @click.prevent.default="showModal()"><i class="fa fa-plus-circle" style="font-size: 1em;"></i> Add Records to Request</a>
    <template v-if="show_modal">
        <div ref="modal" class="modal representation-browse-modal">
            <div class="modal-content">
                <controlled-records title="Add Records to Request">
                    <template v-slot:record_actions="slotProps">
                        <template v-if="isAlreadySelected(slotProps.record)">
                            <button class="btn btn-small red darken-1" @click="removeSelected(slotProps.record)"><i class="fa fa-minus-circle" style="font-size: 1em;"></i> Remove</button>
                        </template>
                        <template v-else-if="isSelectable(slotProps.record)">
                            <button class="btn btn-small" @click="addSelected(slotProps.record)"><i class="fa fa-plus-circle" style="font-size: 1em;"></i> Add</button>
                        </template>
                    </template>
                </controlled-records>
            </div>
            <div class="modal-footer">
                <a href="#!" class="modal-close waves-effect waves-green btn-flat">Close</a>
            </div>
        </div>
    </template>
</div>
`,
    data: function(): {show_modal: boolean} {
        return {
            show_modal: false,
        };
    },
    props: ['selected'],
    methods: {
        showModal: function() {
            this.show_modal = true;
            this.$nextTick(() => {
                const modal: any = M.Modal.init(this.$refs.modal, {
                });
                document.body.appendChild(this.$refs.modal as Element);
                modal.open();
            });
        },
        isAlreadySelected: function(record: Record) {
            return !!Utils.find(this.selected, (representation: RepresentationRequest) => {
                return representation.id === record.id;
            });
        },
        removeSelected: function(record: Record) {
            this.selected.forEach((representation: RepresentationRequest) => {
                if (representation.id === record.id) {
                    (this.$parent as any).removeSelected(representation);
                }
            });
        },
        addSelected: function(record: Record) {
            this.$emit('selected', new RepresentationRequest(record.id, record.title, 'DIGITAL'));
        },
        isSelectable: function(record: Record) {
            return !!Utils.find(record.types, (type: string) => {
                return type === 'representation';
            });
        },
    },
});

