<script lang="ts">
  import BannerPicker from '@/components/BannerPicker.svelte'
  import HelpTip from '@/components/HelpTip.svelte'
  import type { ProjectForm } from '@/lib/projectForm'

  // `brief` is the create form: just what the project is. The banner and links wait for the edit page.
  let {
    form,
    directUploadUrl,
    brief = false,
  }: { form: ProjectForm; directUploadUrl: string | undefined; brief?: boolean } = $props()

  const links = [
    {
      key: 'repo_url',
      label: 'Repository link',
      help: 'Where the code, schematics or CAD files live.',
      placeholder: 'https://github.com/you/thing',
    },
    {
      key: 'demo_url',
      label: 'Demo link',
      help: 'A video, photos or docs showing it working.',
      placeholder: 'https://',
    },
  ] as const
</script>

{#snippet head(id: string, label: string, help: string)}
  <div class="mb-1 flex items-center gap-1.5">
    <label for={id} class="font-outfit text-sm text-ink">{label}</label>
    <HelpTip text={help} />
  </div>
{/snippet}

{#snippet foot(required: boolean, error: string | undefined)}
  <div class="mt-1 flex justify-between gap-3 font-outfit text-xs">
    <span class="text-red-700">{error ?? ''}</span>
    <span class={required ? 'text-red-700' : 'text-ink-soft'}>{required ? 'Required' : 'Optional'}</span>
  </div>
{/snippet}

<div class="space-y-3 md:space-y-4">
  <div>
    {@render head('project-title', 'Title', 'Give your project a name. You can change it later.')}
    <input
      id="project-title"
      name="title"
      type="text"
      maxlength="120"
      bind:value={form.title}
      class="paper-input"
    />
    {@render foot(true, form.errors.title)}
  </div>

  <div>
    {@render head(
      'project-description',
      'Description',
      'What it does, who it is for, and what done looks like.',
    )}
    <textarea
      id="project-description"
      name="description"
      rows="3"
      bind:value={form.description}
      class="paper-input"></textarea>
    {@render foot(false, form.errors.description)}
  </div>

  {#if !brief}
    <div>
      <div class="mb-1 flex items-center gap-1.5">
        <span class="font-outfit text-sm text-ink">Banner</span>
        <HelpTip text="A photo or sketch of what you're building." />
      </div>
      <BannerPicker bind:value={form.banner} {directUploadUrl} />
      {@render foot(false, form.errors.banner)}
    </div>

    {#each links as link (link.key)}
      <div>
        {@render head(`project-${link.key}`, link.label, link.help)}
        <input
          id="project-{link.key}"
          name={link.key}
          type="url"
          placeholder={link.placeholder}
          bind:value={form[link.key]}
          class="paper-input"
        />
        {@render foot(false, form.errors[link.key])}
      </div>
    {/each}
  {/if}
</div>
