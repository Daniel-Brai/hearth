import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router';
import { useGateway } from '@/app/gateway-context';
import { useStore } from '@/data/store';
import { linkKind } from '@/domain/links';
import { resizeErrorText, resizeImage } from '@/features/images';
import { routes } from '@/runtime/routes';
import { sfx } from '@/runtime/sounds';
import { useUi } from '@/runtime/ui-store';
import { useLeaveGuard } from '@/pages/compose/use-leave-guard';
import {
  checkForm,
  formOf,
  newLinkRow,
  snapshotOf,
  type Form,
  type LinkRow,
  type Problem,
} from './edit-profile-form';

export function useEditProfile(me: string, username: string) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);
  const store = useStore();

  const [initial] = useState<Form>(() => formOf(store.get(), me));

  const [form, setForm] = useState(initial);
  const [problem, setProblem] = useState<Problem | null>(null);
  const [shake, setShake] = useState<string | null>(null);

  const dirty = snapshotOf(form) !== snapshotOf(initial);
  const guard = useLeaveGuard(dirty);

  const set = <K extends keyof Form>(key: K, value: Form[K]) =>
    setForm((f) => ({ ...f, [key]: value }));

  const setLink = (id: number, patch: Partial<LinkRow>) =>
    set(
      'links',
      form.links.map((l) => (l.id === id ? { ...l, ...patch } : l)),
    );

  const changeUrl = (l: LinkRow, url: string) => {
    if (!l.auto && l.label.trim()) return setLink(l.id, { url });
    setLink(l.id, { url, label: linkKind(url)?.name ?? '', auto: true });
  };

  const moveLink = (i: number, by: number) => {
    const j = i + by;
    const a = form.links[i];
    const b = form.links[j];

    if (!a || !b) return;

    const next = [...form.links];

    next[i] = b;
    next[j] = a;
    set('links', next);
  };

  const removeLink = (id: number) =>
    set(
      'links',
      form.links.filter((x) => x.id !== id),
    );

  const addLink = () => set('links', [...form.links, newLinkRow()]);

  const pickPhoto = async (file: File | undefined) => {
    if (!file) return;
    const r = await resizeImage(file, 320, 320, true);

    if (r.ok) set('photo', r.dataUrl);
    else flash(resizeErrorText(r.error));
  };

  const fail = (field: string | null, text: string) => {
    sfx('error');
    setProblem({ field, text });
    setShake(field);
    window.setTimeout(() => setShake(null), 450);
  };

  const submit = async (e?: FormEvent) => {
    e?.preventDefault();
    setProblem(null);

    const checked = checkForm(form);

    if (!checked.ok) return fail(checked.field, checked.text);

    const r = await gateway.profile.save(checked.spec);

    if (!r.ok) return fail(null, r.error);

    guard.allowLeave();
    flash('Profile updated');
    void navigate(routes.profile(username));
  };

  return {
    form,
    set,
    problem,
    shake,
    dirty,
    blocker: guard.blocker,
    submit,
    pickPhoto,
    links: { setLink, changeUrl, move: moveLink, remove: removeLink, add: addLink },
  };
}

export type EditProfile = ReturnType<typeof useEditProfile>;
