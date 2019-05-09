/// <amd-module name='file-uploader'/>


import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";

Vue.use(VueResource);

import UI from "./ui";


interface UploadedFile {
    key:String;
    filename:String;
    mime_type:String;
    role?:String;
    created_by?:String;
    create_time?:String;
}

interface ValidationResult {
    valid:boolean;
    errors:Array<string>;
}

interface UploaderState {
    uploaded:UploadedFile[];
    non_deleteable_roles:Array<string>;
    is_readonly:Boolean;
    is_role_enabled:Boolean;
    validation_status:any;
}

Vue.component('file-uploader', {
    template: `
<div>
    <template v-if="!is_readonly">
        <div class="file-field input-field">
            <div class="btn">
                <span>Upload File(s)</span>
                <input type="file" ref="upload" multiple v-on:change="uploadFiles">
            </div>
            <div class="file-path-wrapper">
                <input class="file-path" type="text">
            </div>
        </div>
    </template>
    <template v-if="uploaded.length > 0">
        <div class="card">
            <div class="card-content">
                <table>
                    <thead>
                        <tr>
                            <th style="width: 40%">Filename</th>
                            <template v-if="is_role_enabled">
                                <th>Role</th>
                            </template>
                            <th>Created by</th>
                            <th>Create Time</th>
                            <th>Validated</th>
                            <th></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="file in uploaded">
                            <td>
                                {{file.filename}}
                                <input type="hidden" v-bind:name="buildPath('key')" v-bind:value="file.key"/>
                                <input type="hidden" v-bind:name="buildPath('mime_type')" v-bind:value="file.mime_type"/>
                                <input type="hidden" v-bind:name="buildPath('filename')" v-bind:value="file.filename"/>
                            </td>
                            <template v-if="is_role_enabled">
                                <td>
                                    <template v-if="is_readonly">
                                        {{file.role}}
                                    </template>
                                    <template v-else>
                                        <select :name="buildPath('role')" v-model="file.role" class="browser-default">
                                            <option value="CSV">CSV</option>
                                            <option value="RAP">RAP Notice</option>
                                            <option value="OTHER">Other</option>
                                        </select>
                                    </template>
                                </td>
                            </template>
                            <td>{{file.created_by}}</td>
                            <td>{{formatTime(file.create_time)}}</td>
                            <td>
                              <template v-if="file.role !== 'CSV'">
                                  N/A
                              </template>
                              <template v-else-if="is_valid(file.key)">
                                Validated
                              </template>
                              <template v-else-if="is_not_yet_validated(file.key)">
                                Pending
                              </template>
                              <template v-else>
                                <a href="#" @click.prevent="showErrors(file.key)">Contains Errors</a>
                              </template>
                            </td>
                            <td>
                                <a class="btn" target="_blank" :href="'/file-download?key=' + encodeURIComponent(file.key) + '&filename=' + encodeURIComponent(file.filename) + '&mime_type=' + encodeURIComponent(file.mime_type)">Download</a>
                                <template v-if="!is_readonly && is_deleteable(file.role)">
                                    <a class="btn" v-on:click="remove(file)">Remove</a>
                                </template>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </template>
</div>
`,
    data: function(): UploaderState {
        return {
            uploaded: JSON.parse(this.files),
            non_deleteable_roles: JSON.parse(this.locked_file_roles || "[]"),
            is_readonly: (this.readonly == 'true'),
            is_role_enabled: (this.role == 'enabled'),
            validation_status: {},
        };
    },
    props: ['files', 'csrf_token', 'input_path', 'readonly', 'role', 'submit_button_ids', 'locked_file_roles'],
    methods: {
        uploadFiles: function() {
            let uploadInput = <HTMLInputElement>this.$refs.upload;
            let files:FileList|null = uploadInput.files;

            if (files && files.length > 0) {
                let formData = new FormData();
                for (let i = 0; i < files.length; i++) {
                    let file:File|null = files.item(i);
                    if (file) {
                        formData.append('file[]', file);
                    }
                }
                formData.append('authenticity_token', this.csrf_token);

                // If we were handed the IDs of submit buttons, disable those
                // form inputs until we're done uploading.
                this.disableFormSubmit();

                this.$http.post('/file-upload', formData, {
                    headers: {
                        'Content-Type': 'multipart/form-data'
                    },
                    // emulateJSON: true,
                }).then((response: any) => {
                    return response.json();
                }, (_response: any) => {
                    this.enableFormSubmit();
                    UI.genericModal("File upload failed");
                }).then((json:UploadedFile[]) => {
                    for (let uploadedFile of json) {
                        if (uploadedFile.role == null) {
                            if (uploadedFile.filename.toLowerCase().slice(-3) == 'csv') {
                                uploadedFile.role = 'CSV';
                            } else {
                                uploadedFile.role = 'OTHER';
                            }
                        }
                        this.uploaded.push(uploadedFile);
                    }

                    this.enableFormSubmit();
                });
            }
        },
        is_deleteable(role: string) {
            return this.non_deleteable_roles.indexOf(role) < 0;
        },
        remove(fileToRemove: UploadedFile) {
            this.uploaded = Utils.filter(this.uploaded, (file: UploadedFile) => {
                return fileToRemove.key !== file.key;
            });
        },
        buildPath(field:string) {
            return this.input_path + "[" + field + "]";
        },
        formatTime: function(epochTime:number|null) {
            if (epochTime) {
                return Utils.localDateForEpoch(epochTime);
            } else {
                return '';
            }
        },
        is_valid: function(key:string): boolean {
            if (this.validation_status[key] !== undefined) {
                const status: ValidationResult = (this.validation_status[key] as ValidationResult);
                return status.valid;
            } else {
                return false;
            }
        },
        is_not_yet_validated: function(key:string): boolean {
            return !this.validation_status[key];
        },
        showErrors(key:string) {
            if (this.validation_status[key]) {
                const errors = document.createElement('ul');

                for (const error of this.validation_status[key].errors) {
                    const li = document.createElement('li');
                    li.innerText = error;
                    errors.appendChild(li);
                }

                console.log(errors);

                UI.genericHTMLModal(errors);
            }
        },
        disableFormSubmit() {
            if (this.submit_button_ids) {
                for (const buttonId of this.submit_button_ids) {
                    const button = document.getElementById(buttonId);
                    if (button) {
                        console.log("DISABLE", button);
                        button.classList.add('disabled');
                    }
                }
            }
        },
        enableFormSubmit() {
            if (this.submit_button_ids) {
                for (const buttonId of this.submit_button_ids) {
                    const button = document.getElementById(buttonId);
                    if (button) {
                        button.classList.remove('disabled');
                    }
                }
            }
        },
    },
    watch: {
        uploaded: {
            handler(uploadedFiles) {
                for (const file of uploadedFiles) {
                    if (file.role === 'CSV' && !this.validation_status[file.key]) {
                        this.$http.get('/csv-validate', { params: {key: file.key} }).then((response: any) => {
                            return response.json();
                        }, (_response: any) => {
                            UI.genericModal("Validation failed.  Please retry.");
                        }).then((validationResult:ValidationResult) => {
                            this.validation_status[file.key] = validationResult;
                            this.$forceUpdate();
                        });
                    }
                }
            },
            deep: true,
        }
    },
});
