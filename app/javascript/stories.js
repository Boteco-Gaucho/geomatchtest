// ========================================
// GERENCIAMENTO DE STORIES POR LOCALIZAÇÃO
// ========================================

["DOMContentLoaded", "turbo:load"].forEach((evt) => {
  document.addEventListener(evt, () => {
    initializeStories();
  });
});

function initializeStories() {
  const addStoryBtn = document.getElementById("add-story-btn");
  const addStoryModal = document.getElementById("add-story-modal");
  const modalOverlay = document.getElementById("modal-overlay");
  const closeModalBtn = document.getElementById("close-modal-btn");
  const cancelStoryBtn = document.getElementById("cancel-story-btn");
  const publishStoryBtn = document.getElementById("publish-story-btn");
  const storyUploadArea = document.getElementById("story-upload-area");
  const storyFileInput = document.getElementById("story-file-input");
  const storyCaptionInput = document.getElementById("story-caption");

  // ========================================
  // ABRIR MODAL DE ADICIONAR STORY
  // ========================================
  if (addStoryBtn) {
    addStoryBtn.addEventListener("click", () => {
      addStoryModal.classList.remove("hidden");
      modalOverlay.classList.remove("hidden");
    });
  }

  // ========================================
  // FECHAR MODAL
  // ========================================
  const closeModal = () => {
    addStoryModal.classList.add("hidden");
    modalOverlay.classList.add("hidden");
    storyFileInput.value = "";
    storyCaptionInput.value = "";
  };

  if (closeModalBtn) closeModalBtn.addEventListener("click", closeModal);
  if (cancelStoryBtn) cancelStoryBtn.addEventListener("click", closeModal);
  if (modalOverlay) modalOverlay.addEventListener("click", closeModal);

  // ========================================
  // UPLOAD DE ARQUIVO (DRAG & DROP + CLICK)
  // ========================================
  if (storyUploadArea) {
    storyUploadArea.addEventListener("click", () => {
      storyFileInput.click();
    });

    // Drag and Drop
    storyUploadArea.addEventListener("dragover", (e) => {
      e.preventDefault();
      storyUploadArea.classList.add("drag-over");
    });

    storyUploadArea.addEventListener("dragleave", () => {
      storyUploadArea.classList.remove("drag-over");
    });

    storyUploadArea.addEventListener("drop", (e) => {
      e.preventDefault();
      storyUploadArea.classList.remove("drag-over");

      const files = e.dataTransfer.files;
      if (files.length > 0) {
        storyFileInput.files = files;
        handleFileSelect();
      }
    });
  }

  // ========================================
  // MANIPULAR SELEÇÃO DE ARQUIVO
  // ========================================
  function handleFileSelect() {
    const file = storyFileInput.files[0];
    if (!file) return;

    const isImage = file.type.startsWith("image/");
    const isVideo = file.type.startsWith("video/");

    if (!isImage && !isVideo) {
      alert("Por favor, selecione uma imagem ou vídeo.");
      storyFileInput.value = "";
      return;
    }

    // Mostrar preview
    const reader = new FileReader();
    reader.onload = (e) => {
      const preview = document.createElement("div");
      preview.className = "story-preview";

      if (isImage) {
        preview.innerHTML = `<img src="${e.target.result}" alt="Preview">`;
      } else if (isVideo) {
        preview.innerHTML = `<video src="${e.target.result}" controls></video>`;
      }

      const existingPreview = storyUploadArea.querySelector(".story-preview");
      if (existingPreview) {
        existingPreview.remove();
      }

      storyUploadArea.appendChild(preview);
      storyUploadArea.classList.add("has-file");
    };

    reader.readAsDataURL(file);
  }

  if (storyFileInput) {
    storyFileInput.addEventListener("change", handleFileSelect);
  }

  // ========================================
  // PUBLICAR STORY
  // ========================================
  if (publishStoryBtn) {
    publishStoryBtn.addEventListener("click", async () => {
      const file = storyFileInput.files[0];
      if (!file) {
        alert("Por favor, selecione uma imagem ou vídeo.");
        return;
      }

      const caption = storyCaptionInput.value.trim();
      const formData = new FormData();
      formData.append("story[media]", file);
      formData.append("story[caption]", caption);

      try {
        publishStoryBtn.disabled = true;
        publishStoryBtn.textContent = "Publicando...";

        const token = document
          .querySelector('meta[name="csrf-token"]')
          .getAttribute("content");

        const response = await fetch("/stories", {
          method: "POST",
          headers: {
            "X-CSRF-Token": token,
          },
          body: formData,
        });

        if (response.ok) {
          alert("✅ Story publicado com sucesso!");
          closeModal();
          loadStories(); // Recarregar stories
        } else {
          const data = await response.json().catch(() => ({}));
          alert(`Erro: ${data.error || response.statusText}`);
        }
      } catch (error) {
        console.error("Erro ao publicar story:", error);
        alert("⚠️ Falha ao publicar story.");
      } finally {
        publishStoryBtn.disabled = false;
        publishStoryBtn.textContent = "Publicar";
      }
    });
  }

  // ========================================
  // CARREGAR STORIES
  // ========================================
  loadStories();
}

async function loadStories() {
  try {
    const response = await fetch("/stories");
    const stories = await response.json();

    const storiesCarousel = document.getElementById("stories-carousel");
    if (!storiesCarousel) return;

    storiesCarousel.innerHTML = "";

    if (stories.length === 0) {
      storiesCarousel.innerHTML = `
        <div class="empty-stories">
          <p>Nenhum story por aqui ainda. Seja o primeiro a compartilhar! 📸</p>
        </div>
      `;
      return;
    }

    stories.forEach((story) => {
      const storyElement = createStoryElement(story);
      storiesCarousel.appendChild(storyElement);
    });
  } catch (error) {
    console.error("Erro ao carregar stories:", error);
  }
}

function createStoryElement(story) {
  const storyDiv = document.createElement("div");
  storyDiv.className = "story-item";
  storyDiv.dataset.storyId = story.id;

  const isVideo = story.media_type === "video";
  const mediaTag = isVideo ? "video" : "img";
  const mediaSrc = story.media_url;

  storyDiv.innerHTML = `
    <div class="story-media">
      <${mediaTag} src="${mediaSrc}" alt="Story" ${isVideo ? "controls" : ""} />
      <div class="story-overlay">
        <div class="story-user-info">
          <img src="${story.user_avatar_url}" alt="${story.user_name}" class="story-avatar">
          <div class="story-user-details">
            <p class="story-user-name">${story.user_name}</p>
            <p class="story-time">${formatTime(story.created_at)}</p>
          </div>
        </div>
      </div>
    </div>
    <div class="story-caption">${story.caption || ""}</div>
  `;

  storyDiv.addEventListener("click", () => {
    openStoryViewer(story);
  });

  return storyDiv;
}

function openStoryViewer(story) {
  // Implementar visualizador de story em fullscreen (opcional)
  console.log("Abrir story:", story);
}

function formatTime(timestamp) {
  const date = new Date(timestamp);
  const now = new Date();
  const diffMs = now - date;
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return "agora";
  if (diffMins < 60) return `${diffMins}m atrás`;
  if (diffHours < 24) return `${diffHours}h atrás`;
  if (diffDays < 7) return `${diffDays}d atrás`;

  return date.toLocaleDateString("pt-BR");
}