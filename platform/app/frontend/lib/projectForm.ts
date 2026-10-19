import { useForm } from '@inertiajs/svelte'
import { projects } from '@/routes'
import type { Project } from '@/types'

// The create and edit modals and the form page share these fields and how they're sent.
export function projectForm(project: Project | null) {
  return useForm({
    title: project?.title ?? '',
    description: project?.description ?? '',
    repo_url: project?.repo_url ?? '',
    demo_url: project?.demo_url ?? '',
    banner: project?.banner ?? null,
  })
}

export type ProjectForm = ReturnType<typeof projectForm>

export function saveProject(
  form: ProjectForm,
  project: Project | null,
  root: HTMLElement,
  onSuccess?: () => void,
  // The edit modal stays where it was on the project page it returns to.
  { preserveScroll = false } = {},
) {
  form
    .transform((data) => ({ project: { ...data, banner: data.banner?.id ?? '' } }))
    .submit(project ? projects.update(project.id) : projects.create(), {
      onSuccess,
      preserveScroll,
      // Focus the first field the server rejected.
      onError: (errors) => root.querySelector<HTMLElement>(`[name="${Object.keys(errors)[0]}"]`)?.focus(),
    })
}
