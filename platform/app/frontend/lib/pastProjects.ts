// Past Hack Club hardware projects for the landing page (from fallout.hackclub.com's "See what teens are building"),
// with names and descriptions as Hack Club lists them (macondo.hackclub.com) and each project's source on GitHub.
import cyberpad from '@/assets/projects/cyberpad.webp'
import glowpad from '@/assets/projects/glowpad.webp'
import angel from '@/assets/projects/angel.webp'
import meko from '@/assets/projects/meko.webp'
import bitlace from '@/assets/projects/bitlace.webp'
import motherboard from '@/assets/projects/3dpmotherboard.webp'
import twoswap from '@/assets/projects/twoswap.webp'

export type PastProject = { image: string; name: string; about: string; by: string; repo: string }

export const pastProjects: PastProject[] = [
  {
    image: cyberpad,
    name: 'CyberPad',
    about: 'A sleek, cyberpunk inspired macropad',
    by: 'Kai (17)',
    repo: 'https://github.com/KaiPereira/CYBERPAD-01',
  },
  {
    image: glowpad,
    name: 'GlowPad',
    about: 'A glowing macropad',
    by: 'Raygen (17)',
    repo: 'https://github.com/lordbagel42/glowpad',
  },
  {
    image: angel,
    name: 'The Biblically Accurate Macropad',
    about: 'A macropad in the form of a biblically accurate angel',
    by: 'Alex (16)',
    repo: 'https://github.com/geg-tech/biblicallyaccuratekeyboard',
  },
  {
    image: meko,
    name: 'Meko',
    about: 'A high definition music player',
    by: 'Marcell (17)',
    repo: 'https://github.com/KOEGlike/meko',
  },
  {
    image: bitlace,
    name: 'Bitlace',
    about: 'A retro accessory with an 8x8 monochrome screen',
    by: 'Vladislav (17)',
    repo: 'https://github.com/glutesha/bitlace',
  },
  {
    image: motherboard,
    name: '3DP Motherboard',
    about: 'A powerful, yet affordable 3D printer motherboard',
    by: 'Kai (17)',
    repo: 'https://github.com/KaiPereira/Cheetah-MX4-Mini',
  },
  {
    image: twoswap,
    name: 'TwoSwap',
    about: 'An epic wearable TV head',
    by: 'Nick (18)',
    repo: 'https://github.com/autowattage/2swap',
  },
]
