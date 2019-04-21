/// <amd-module name='ui'/>

declare var M: any;

export default class UI {
    public static genericModal(message: string) {
        const modal = document.createElement('div');
        const content = document.createElement('div');
        modal.appendChild(content);

        modal.className = 'modal';
        content.className = 'modal-content';

        content.innerText = message;

        document.body.appendChild(modal);

        M.Modal.init(modal).open();
    }
}
