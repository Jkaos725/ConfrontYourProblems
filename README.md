# ConfrontYourProblems

TruHacks 2026

Created by:
- Amen Bush
- Jacob Butterhorn
- Quoc Nguyen

## Overview

ConfrontYourProblems is an AI-powered escape room study game built to make college learning more interactive. Instead of using a standard chatbot or static quiz, the project turns studying into a challenge-based experience where players solve clues, answer questions, and progress through rooms.

The goal was to respond to the theme **AI Solutions to College Level Problems** by creating something more engaging than traditional study tools. Many students struggle with motivation, attention, and retention when using regular study methods. This project approaches that problem by combining AI tutoring with a game format.

## Problem

A lot of college study tools feel repetitive, passive, or boring. Students often lose focus when reviewing notes, using flashcards, or reading the same material over and over again. Standard AI tools can help answer questions, but they do not always make the learning process engaging.

## Solution

This project turns studying into an escape-room experience supported by AI. Players move through challenges by solving clues and responding to educational prompts. The game generates room content from uploaded notes using AI.

At the moment, uploaded notes are supported as **`.txt` files only**.

This makes studying more interactive while still keeping the educational goal at the center.

## Features

- Escape-room style progression
- AI-supported study flow
- `.txt` file upload support
- Multiple room interactions
- Clue and response system
- Professor-based game flavor
- Godot-based game interface

## Why This Is Innovative

Instead of building another chatbot or simple quiz app, we used AI in a more interactive way. The project combines:

- game-based learning
- AI-generated educational content
- a room progression system
- a more engaging interface than a standard study form

This creates a study experience that feels more active and memorable.

## Real-World Use

This project can be useful for students who want a more interactive way to review class material. It could be used for:

- personal studying
- review before quizzes or exams
- classroom learning activities
- turning lecture notes into practice challenges

The idea could be expanded for different subjects, classrooms, and learning styles.

## User Experience

The project is designed so users can:

- start from a main menu
- choose a challenge path
- upload notes as `.txt` files
- interact with clues and response areas
- progress through rooms as they solve challenges

The goal was to make the experience clearer, more interactive, and more game-like than a normal quiz layout.

## Implementation

The project was built in **Godot** using **GDScript**.  
AI-supported features use the **Groq API**.

We chose Godot because it was familiar for development, and GDScript has syntax similar to Python, which made collaboration easier.

## Tools Used

- Godot Engine
- GDScript
- Groq API

## How to Run the Code

### Option 1: Run via Releases (Recommended)

Go to the **Releases** section of this GitHub repository and download the exported build for your system.  
Run the executable directly.

### Option 2: Run in Godot

You can run and view the project on desktop from here:  
https://godotengine.org/

Make sure to:

- Run **Godot v4.6.1-stable** without the console
- Clone the project
- Open Godot
- Import the project
- Go to the project location
- Click the project file
- Open it in the editor

## API Key Setup

In the local project folder, create a file named `Config.cfg`.

Add a Groq key like this:

```ini
[application]
groq_api_key="API-KEY"
