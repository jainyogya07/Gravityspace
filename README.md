# Gravity Paint Studio 🌌

> "Matter tells space-time how to curve, and space-time tells matter how to move." — John Archibald Wheeler

Welcome to **Gravity Paint Studio** (also known as *Gravityspace*), an interactive exploration of particle physics and general relativity, built natively for Apple Silicon using **Swift 5.9** and **Metal**.

This isn't just a tech demo; it's a digital meditation on chaos and order. It simulates **200,000 particles** in real-time, treating your cursor as a massive celestial body that bends the fabric of the digital canvas, pulling particles into orbit, creating accretion disks, and weaving complex tapestries of light.

![Concept](https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjEx.../giphy.gif) 
*(Note: Replace with actual screenshot/gif if available)*

## 🍎 The Technology

We pushed the **M-series chips** to their limit to ensure 120fps buttery-smooth visuals.
- **Compute Shaders**: All physics calculations happen directly on the GPU using custom Metal kernels.
- **Strict Concurrency**: Built with Swift 6 readiness in mind, ensuring thread safety even at high velocities.
- **Hardware Acceleration**: Utilizing the Unified Memory Architecture for zero-copy data transfer between CPU and GPU.

## 🎮 Controls

The universe is at your fingertips:

- **Move Mouse/Touch**: Move the "Gravity Well" (your brush).
- **Click/Drag**: Intensify the gravity (Mass increases).
- **Release**: Gravity weakens, allowing particles to drift.

**Keyboard Shortcuts:**
- `SPACE`: **Pause/Resume** time (Freeze the chaos).
- `R`: **Big Bang** (Reset all particles for a fresh start).
- `1`: **Neon Mode** (Default cyberpunk aesthetic).
- `2`: **Fire Mode** (Thermonuclear dynamics).
- `3`: **Ice Mode** (Sub-zero entropy).

## 🛠️ Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/jainyogya07/Gravityspace.git
    cd Gravityspace
    ```
2.  Run with Swift:
    ```bash
    swift run
    ```
    *Note: Requires macOS 14 (Sonoma) or later.*

## 🧠 The "Why"

I built this project to answer a simple question: **What does gravity _feel_ like?** 
Equations on a chalkboard are one thing, but seeing thousands of pixels swirl into a black hole of your own creation is another. It’s a bridge between code, art, and the fundamental forces of our universe.

## 📄 License
MIT License. Feel free to fork, modify, and build your own universes.

---
*Created with ❤️ by [Yogya Jain](https://github.com/jainyogya07)*
