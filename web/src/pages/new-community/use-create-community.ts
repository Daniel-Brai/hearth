import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { canRequestCommunity } from '@/domain/selectors';
import type { Template } from '@/domain/types';
import { resizeErrorText, resizeImage } from '@/features/images';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { useLeaveGuard } from '@/pages/compose/use-leave-guard';
import { EMPTY, type Form } from './form';

export function useCreateCommunity() {
  const gateway = useGateway();
  const navigate = useNavigate();
  const openDialog = useUi((s) => s.openDialog);
  const flash = useUi((s) => s.flash);
  const asRequest = useAppState((state) => canRequestCommunity(state));

  const [template, setTemplate] = useState<Template | null>(null);
  const [form, setForm] = useState<Form>(EMPTY);
  const [busy, setBusy] = useState(false);
  const [shake, setShake] = useState(false);

  const dirty =
    !!template && (!!form.name.trim() || !!form.tagline.trim() || !!form.description.trim());
  const guard = useLeaveGuard(dirty);

  const set = <K extends keyof Form>(key: K, value: Form[K]) =>
    setForm((f) => ({ ...f, [key]: value }));

  const pickTemplate = (t: Template) => {
    setTemplate(t);
    set('audience', t.visibility === 'invite' ? 'invite' : 'indexed');
  };

  const pickLogo = async (file: File | undefined) => {
    if (!file) return;
    const r = await resizeImage(file, 256, 256, true);

    if (r.ok) set('logo', r.dataUrl);
    else flash(resizeErrorText(r.error));
  };

  const submit = async () => {
    if (!template) return;

    if (!form.name.trim()) {
      setShake(true);
      window.setTimeout(() => setShake(false), 450);
      return;
    }

    setBusy(true);

    let r: Awaited<ReturnType<typeof gateway.communities.create>>;

    try {
      r = await gateway.communities.create({ ...form, template: template.id });
    } finally {
      setBusy(false);
    }

    if (!r.ok) {
      flash(r.error);
      return;
    }

    guard.allowLeave();

    if (r.value.requested) {
      flash("Request sent. You'll hear back when the admin decides.");
      void navigate(routes.home);
      return;
    }

    if (r.value.community) {
      flash(form.name.trim() + ' is ready');
      void navigate(routes.community(r.value.community));
      openDialog('welcome', { community: r.value.community });
    }
  };

  return {
    asRequest,
    template,
    form,
    busy,
    shake,
    blocker: guard.blocker,
    set,
    pickTemplate,
    clearTemplate: () => setTemplate(null),
    pickLogo,
    submit,
  };
}
