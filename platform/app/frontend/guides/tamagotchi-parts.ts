import { workshopGuide } from '@/routes'

// The Tamagotchi guide's main pages, in order. Each part's sections are the files in guides/<folder>, ordered by their
// frontmatter. PCB is the guide's home at /tamagotchi; the others are /tamagotchi/<id> (PARTS in
// WorkshopGuidesController).
export const parts = [
  { id: 'pcb', title: 'PCB', folder: 'tamagotchi' },
  { id: 'cad', title: 'CAD', folder: 'tamagotchi-cad' },
  { id: 'firmware', title: 'Firmware', folder: 'tamagotchi-firmware' },
  { id: 'submit', title: 'Submit & finish', folder: 'tamagotchi-submit' },
]

export const partUrl = (id: string) => workshopGuide(id === 'pcb' ? {} : { page: id }).url
